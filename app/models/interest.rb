# An interest, e.g. "intellectual property". 
#
# ## "search" interests
#
# Alice searches for an interest of hers, "intellectual property", filters for
# "Bills in Congress," and signs up for notifications. This creates a "search"
# interest. The interest is *in* "intellectual property". It also creates a
# single subscription, whose adapter is the `federal_bills` adapter. Alice will
# receive notifications about new items related to her interest from the data
# source for that adapter, Sunlight's Congress API.
#
# If Alice did not filter for "Bills in Congress", Scout creates a subscription
# for each adapter that is a "search-type" adapter (currently hardcoded).
#
# ## "item" interests
#
# Alice navigates to the page of a single item, e.g. a bill, and signs up for
# notifications. This creates an "item" interest. The interest is *in* the item.
# It also creates subscriptions to adapters for things related to the item, like
# votes, notices of upcoming hearings, etc. Alice will receive notifications
# about new items related to the item from the data sources for those adapters.
#
# ## "feed" interests
#
# Alice imports an RSS feed into Scout. This creates a "feed" interest. The
# interest is *in* the feed. It also creates a single subscription, whose
# adapter is the `feed` adapter. Alice will receive notifications about new
# items in the feed. (In other words, this is RSS-to-Email.)
#
# ## "tag" interests
#
# These interests have no subscriptions and are specially handled. See the
# `Delivery` class for more discussion.
#
# Read `Interest#subscriptions_for` for more understanding.
class Interest
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  has_many :subscriptions, dependent: :destroy
  has_many :seen_items, dependent: :destroy
  has_many :deliveries, dependent: :destroy

  # @return [String] what the user is interested in, which varies according to
  #   the value of `interest_type`:
  #   * "feed": a feed URL
  #   * "item": the item's `item_id`
  #   * "search": search terms
  #   * "tag": the tag's ID
  field :in

  # @return [String] normalized search terms, useful for deduping
  # @note Only set if the interest is in search terms.
  field :in_normal

  # @return [String] one of "feed", "item", "search" or "tag"
  field :interest_type

  # @return [String] either "all" or a subscription adapter's lowercase
  #   underscored name
  # @note Only relevant if the interest is in search terms.
  field :search_type
  # @return [String] either "simple" or "advanced"
  # @note Only relevant if the interest is in search terms.
  field :query_type

  # @return [String] the item's type, e.g. "bill"
  # @note Only relevant if the interest is in an item.
  field :item_type

  # @return [Hash] arbitrary metadata, which varies depending according to the
  #   value of `interest_type`:
  #   * "feed": the feed's URL, title, description, etc.
  #   * "item": a copy of the item's metadata, e.g. "bill_id" => "hr2134-112"
  #   * "search": filters, e.g. "stage" => "passed_house"
  #   * "tag": nothing
  field :data, type: Hash, default: {}

  # query metadata, not persisted.
  # citations, operators extracted from the query,
  # and the revised query string after post-processing.
  # @return a query
  def query; @query ||= query!; @query; end

  # @return [Array<String>] a list of user-set tags for this interest
  field :tags, type: Array, default: []

  # @return [String] the interest's notification settings, which override the
  #   user's global notification settings:
  #   * "email_immediate": the user will receive notifications immediately
  #   * "email_daily" the user will receive notifications daily
  #   * "sms": the user will receive both an SMS and email immediately
  #   * "none": the user will not receive notifications
  field :notifications
  validates_inclusion_of :notifications, :in => ["none", "email_daily", "email_immediate", "sms"], :allow_blank => true

  index in: 1
  index user_id: 1
  index interest_type: 1
  index search_type: 1
  index item_type: 1
  index tags: 1
  index({user_id: 1, tags: 1})

  validates_presence_of :user_id
  validates_presence_of :in

  scope :for_time, ->(start, ending) {where(created_at: {"$gt" => Time.zone.parse(start).midnight, "$lt" => Time.zone.parse(ending).midnight})}

  before_destroy :record_unsubscribe
  # @private
  def record_unsubscribe
    Event.remove_alert! self
  end

  # when a search interest is saved, flash a normalized version of the query for use in de-duping
  before_save :normalize_query, :if => :search?
  # @private
  def normalize_query
    self.in_normal = Search.normalize self.query
  end

  def title
    Subscription.adapter_for(item_types[self.item_type]['adapter']).title_for self.data
  end

  # @return [Boolean] whether the interest is in an item
  def item?
    interest_type == "item"
  end

  # @return [Boolean] whether the interest is in a feed
  def feed?
    interest_type == "feed"
  end

  # @return [Boolean] whether the interest is in search terms
  def search?
    interest_type == "search"
  end

  # @return [Boolean] whether the interest is in a collection
  def tag?
    interest_type == "tag"
  end

  def self.public_json_fields
    [
      'created_at', 'updated_at', 'interest_type', 'in', 'item_type', 'search_type'
    ]
  end

  def new_tags=(names)
    self.tags = names.split(/\s*,\s*/).map do |tag|
      Tag.normalize tag
    end.select(&:present?).uniq
  end

  # for a tag interest only, fetches the associated tag
  def tag
    @tag ||= Tag.find self.in
  end

  # for a tag interest only, fetches and caches the associated sharing user
  def tag_user
    @tag_user ||= tag.user
  end

  # XXX unused
  def tags_display
    self.tags.join ", "
  end


  # other interests following this interest.
  # only makes sense for a saved interest with a user that owns it
  def followers
    # for non-tag interests only
    return [] if self.tag?

    # does the user owning this interest have it included in any of their public tags?
    public_tag_ids = user.tags.where(:public => true, name: {"$in" => self.tags}).map {|tag| tag.id.to_s}
    return [] unless public_tag_ids.any?

    # anyone's interests following any of those public tags
    Interest.where :interest_type => "tag", :in => {"$in" => public_tag_ids}
  end


  # the mechanism this subscription prefers to be delivered as (e.g. email or SMS).
  # for right now, reads right from the user's preferences, but could be changed
  # to be per-interest or per-subscription.
  def mechanism
    preference = self.notifications || user.notifications

    if preference =~ /email/
      "email"
    elsif preference == "sms"
      "sms"
    else
      nil
    end
  end

  def email_frequency
    preference = self.notifications || user.notifications
    if preference == "email_immediate"
      "immediate"
    elsif preference == "email_daily"
      "daily"
    else
      nil
    end
  end


  # for search interests only -
  # any keys inside the 'data' field that match the adapter's filter keys
  # Important: 'all' search subscriptions are assumed to have no filters
  def filters
    if @filters
      @filters
    else
      # 'all' search types cannot filter
      if search_type == "all"
        @filters = {}
      else
        adapter = Subscription.adapter_for search_type
        filter_fields = adapter.respond_to?(:filters) ? adapter.filters.keys : []
        fields = data.dup
        fields.keys.each {|key| fields.delete(key) unless filter_fields.include?(key)}
        @filters = fields
      end
    end
  end

  def filter_name(field, value)
    if search_type != "all"
      adapter = Subscription.adapter_for search_type
      if adapter.respond_to?(:filters)
        adapter.filters[field.to_s][:name].call value
      end
    end
  end

  # run processing on the interest to extract additional data useful for display and logic
  # does not need to be stored with the interest, or used for de-duping, but helpful
  # idempotent, clears itself, can be run over and over
  # @private
  def query!
    query = {}

    if self.query_type == "advanced"
      query.merge! Search.parse_advanced(self.in)
    else
      query.merge! Search.parse_simple(self.in)
    end

    # citations should at least be an empty array (could remove this req)
    query['citations'] ||= []

    query
  end

  # does the user have an interest with this criteria, and this data hash?
  # optional: a 'populate' hash for attributes to be set on new records,
  #           but which should not be used to constrain lookup of existing records
  # @private
  def self.for(user, criteria, data = nil)

    # if no data given, then we don't care whether the data differs,
    # and we can do a much simpler lookup
    if data.nil?
      interest = if user
        user.interests.find_or_initialize_by criteria
      else
        Interest.new criteria
      end

    else
      find_criteria = criteria.dup

      criteria['data'] = data
      data.each {|key, value| find_criteria["data.#{key}"] = value}

      interest = if user
        # we use dot notation for the criteria instead of passing in a hash, because
        # apparently hash key order is important in matching on the subdocument,
        # which is ridiculous.
        #
        # however, the approach of finding with dot notation means that we could find results
        # that have fields we didn't ask for, which would not be right.
        #
        # the only approach I've found so far is to find all candidates using dot notation,
        # then filter the too-broad ones client-side.
        interest = user.interests.where(find_criteria).detect do |interest|
          interest.data.keys.select {|key| !data.keys.include?(key)}.empty?
        end

        interest || user.interests.new(criteria)
      else
        Interest.new criteria
      end

    end

    interest
  end

  # does the user have a search interest for this query, of this
  # search type ("all" or an individual type), and this set of filters?
  def self.for_search(user, search_type, interest_in, query_type, filters = {})
    # choke unless interest_in and query_type are present
    return nil unless interest_in.present? and query_type.present?

    filters ||= {} # in case nil is passed in

    # match on normalized interest (post-processing)
    if query_type == "simple"
      query = Search.parse_simple interest_in
    else
      query = Search.parse_advanced interest_in
    end
    in_normal = Search.normalize query

    criteria = {
      'interest_type' => 'search',
      'search_type' => search_type,
      'query_type' => query_type,
      'in_normal' => in_normal
    }

    # assign original interest_in, even though it's not used to look up the query
    interest = self.for user, criteria, filters
    interest.in = interest_in

    interest
  end

  # if this is used to make a new item, the caller will have to
  # fetch and populate the item's relevant data
  def self.for_item(user, item_id, item_type)
    criteria = {
      'in' => item_id,
      'interest_type' => 'item',
      'item_type' => item_type
    }

    self.for user, criteria
  end

  # if this is used to make a new feed, the caller will have to
  # fetch the feed's title, description, site URL, and other details
  def self.for_feed(user, url)
    criteria = {
      'in' => url,
      'interest_type' => 'feed'
    }

    self.for user, criteria
  end

  # if this is used to make a new tag, the caller will have to
  # populate the data hash with the tag's name
  def self.for_tag(user, sharing_user, shared_tag)
    criteria = {
      'in' => shared_tag.id.to_s, # store as string
      'interest_type' => 'tag'
    }

    self.for user, criteria
  end

  # find or initialize all the subscriptions an interest should have,
  # inferrable from the interest's type and subject
  def self.subscriptions_for(interest, regenerate = false)
    if !interest.new_record?
      unless regenerate
        return interest.subscriptions.all
      end
    end

    subscription_types = if interest.search?
      if interest.search_type == "all"
        if interest.query['citations'].any?
          cite_types
        else
          search_types
        end
      else
        [interest.search_type]
      end
    elsif interest.item?
      item_types[interest.item_type]['subscriptions'] || []
    elsif interest.feed?
      ["feed"]
    elsif interest.tag?
      [] # no subscriptions, others' handle it
    end

    subscription_types.map {|type| subscription_for interest, type, regenerate}
  end

  # look up or generate a single subscription for this interest
  # assumes an interest can have at most one subscription of a particular type
  def self.subscription_for(interest, subscription_type, regenerate = false)
    # if the interest is created, and we're not asking for regeneration,
    # we can count on the interest having it
    if !interest.new_record? and !regenerate
      return interest.subscriptions.where(subscription_type: subscription_type).first
    end

    if interest.new_record?
      subscription = interest.subscriptions.new subscription_type: subscription_type
    else
      subscription = interest.subscriptions.find_or_initialize_by subscription_type: subscription_type
    end

    # TODO: refactor these all away, make the subscription worth only its type
    subscription.interest_in = interest.in
    subscription.user = interest.user
    subscription.data = interest.data.dup
    subscription.query = interest.query.dup # not persisted data
    subscription.query_type = interest.query_type # man, get rid of this stuff

    subscription
  end


  # before create, wipe any subscriptions that have been initialized away,
  # regenerate them, and save them

  # split up before and after create because the subscriptions_for method
  # (currently) will just look up existing subscriptions if the interest has an id
  before_create :ensure_subscriptions
  # @private
  def ensure_subscriptions
    self.subscriptions = Interest.subscriptions_for self
  end

  after_create :create_subscriptions
  # @private
  def create_subscriptions(init = true)
    self.subscriptions.each do |subscription|
      subscription.save!
      Subscriptions::Manager.initialize!(subscription) if init
    end
  end

  # minimal representation to remote services
  def to_remote
    details = {_id: _id.to_s, interest_type: interest_type, updated_at: updated_at, created_at: created_at}

    if interest_type == "item"
      details.merge!("in" => self.in, item_type: item_type)
    elsif interest_type == "search"
      details.merge!("in" => self.in, query_type: query_type, filters: filters)
    end

    details
  end

end

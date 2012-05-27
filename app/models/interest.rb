class Interest
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :user
  has_many :subscriptions, :dependent => :destroy
  has_many :seen_items # convenience, subscriptions will do the destroy on them

  # a search string or item ID
  field :in

  # 'search', or 'item'
  field :interest_type

  # if interest_type is a "search", can be "all" or the subscription_type in question
  field :search_type 

  # if interest_type is an "item", the item type (e.g. 'bill')
  field :item_type

  # arbitrary metadata
  #   search query - metadata about the search query
  #     (e.g. "query" => "copyright")
  #   item - metadata about the related item 
  #     (e.g. "chamber" => "house", "state" => "NY", "bill_id" => "hr2134-112")
  field :data, :type => Hash, :default => {}

  # tags the user has set on this interest
  field :tags, :type => Array, :default => []

  # per-interest override of notification mechanism
  field :notifications
  validates_inclusion_of :notifications, :in => ["none", "email_daily", "email_immediate", "sms"], :allow_blank => true
  
  index :in
  index :user_id
  index :interest_type
  
  validates_presence_of :user_id
  validates_presence_of :in
  
  
  def item?
    interest_type == "item"
  end

  def feed?
    interest_type == "external_feed"
  end

  def search?
    interest_type == "search"
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

  def tags_display
    self.tags.join ", "
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

  # does the user have a search interest of this search type ("all" or an individual type), and this data hash?
  def self.search_for(user, search_type, interest_in, data = {})

    criteria = {
      'in' => interest_in,
      'interest_type' => 'search',
      'search_type' => search_type,
    }
    find_criteria = criteria.dup

    if data
      criteria['data'] = data
    end

    data.each {|key, value| find_criteria["data.#{key}"] = value}

    if user
      # we use dot notation for the criteria instead of passing in a hash, because
      # apparently hash key order is important in matching on the subdocument, which is ridiculous.
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

end
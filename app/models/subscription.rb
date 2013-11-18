# A subscription to a data source.
#
# A user creates an interest, e.g. "intellectual property", and chooses to
# receive new items related to that interest from all data sources. The interest
# will have one or more *subscriptions* per data source. For example, if a user
# has an interest in state bills about agriculture, they may be suscribed to not
# only new bills, but also new actions and new votes on those bills.
class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps

  # @return [String] the lowercase underscored name of this subscription's adapter
  field :subscription_type
  # @return [Boolean] whether the subscription is initialized
  field :initialized, type: Boolean, default: false
  # @return [String] what the user is interested in (terms, feed URL, etc.)
  field :interest_in
  # XXX redundant with `belongs_to :interest`?
  field :interest_id
  # @return [Time] the time at which the subscription was last checked
  field :last_checked_at, type: Time

  # @return [Hash] an arbitrary set of parameters that may refine or alter the
  #   subscription, e.g. `{"state" => "NY"}`
  field :data, type: Hash, default: {}
  # @return [String] either "simple" or "advanced"
  field :query_type # can't wait to ditch this

  # @return a query
  def query; interest ? interest.query : @query; end
  # @param obj
  def query=(obj); @query = obj; end

  index subscription_type: 1
  index initialized: 1
  index user_id: 1
  index interest_in: 1
  index last_checked_at: 1
  index interest_id: 1
  index user_id: 1

  has_many :seen_items
  has_many :deliveries
  belongs_to :user
  belongs_to :interest

  validates_presence_of :user_id
  validates_presence_of :subscription_type

  # this validation will fall
  validate do
    if interest_in.blank?
      errors.add(:base, "Enter a keyword or phrase to subscribe to.")
    end
  end

  scope :initialized, where(initialized: true)
  scope :uninitialized, where(initialized: false)

  # @return [Class] this subscription's adapter
  def adapter
    Subscription.adapter_for subscription_type
  end

  # @param [String] type a subscription adapter's lowercase underscored name
  # @return [Class] the matching adapter
  def self.adapter_for(type)
    adapter_map[type]
  end

  # Sends an API request for all documents relevant to the subscription and
  # returns them as a list of items.
  #
  # @param [Hash] options
  # @option options [String] :api_key an API key
  # @option options [Integer] :page a page number
  # @option options [Integer] :per_page the number of items per page
  # @option options [Boolean] :cache_only if truthy and if the cache contains no
  #   cached response of a request to the data source, then no requests are sent
  #   to the data source and `nil` is returned
  # @return [Array<SeenItem>,Hash] the items from the data source that match
  #   this subscription's query, or an error hash
  def search(options = {})
    Subscriptions::Manager.search self, options
  end

  # @return [String] the adapter's long human name
  def search_name
    adapter.search_name self
  end

  # @param [Hash] options
  # @option options [String] :api_key an API key
  # @option options [Integer] :page a page number
  # @option options [Integer] :per_page the number of items per page
  # @return [String] a URL with which to search the adapter's data source
  def search_url(options = {})
    adapter.url_for self, :search, options
  end

  # @return [Hash] a copy of the subscription's `data` hash that includes only
  #   fields that match the adapter's fields
  def filters
    if @filters
      @filters
    else
      filter_fields = adapter.respond_to?(:filters) ? adapter.filters.keys : []
      fields = data.dup
      fields.keys.each {|key| fields.delete(key) unless filter_fields.include?(key)}
      @filters = fields
    end
  end

  # @param [String] field a facet field's name
  # @param value a machine-readable facet value, e.g. "1"
  # @return [String] a human-readable facet value, e.g. "Passed lower chamber"
  def filter_name(field, value)
    if adapter.respond_to?(:filters)
      adapter.filters[field.to_s][:name].call value
    end
  end
end

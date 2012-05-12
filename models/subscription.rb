class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscription_type
  field :initialized, :type => Boolean, :default => false
  field :interest_in
  field :interest_id
  field :last_checked_at, :type => Time

  # arbitrary set of parameters that may refine or alter the subscription (e.g. "state" => "NY")
  field :data, :type => Hash, :default => {}

  # used as a display helper on the search page
  field :slug
  
  index :subscription_type
  index :initialized
  index :user_id
  index :interest_in
  index :last_checked_at
  
  has_many :seen_items, :dependent => :delete
  has_many :deliveries, :dependent => :destroy
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
  
  scope :initialized, :where => {:initialized => true}
  scope :uninitialized, :where => {:initialized => false}
  
  # adapter class associated with a particular subscription
  def adapter
    Subscription.adapter_for subscription_type
  end

  def self.adapter_for(type)
    "Subscriptions::Adapters::#{type.camelize}".constantize rescue nil
  end
  
  def search(options = {})
    Subscriptions::Manager.search self, options
  end
  
  after_create :initialize_self
  def initialize_self
    Subscriptions::Manager.initialize! self
  end

  def search_name
    adapter.search_name self
  end

  def search_url(options = {})
    adapter.url_for self, :search, options
  end

  # the path within Scout for this subscription
  # assumes this is a search-type subscription
  def scout_search_url(options = {})
    subscription_type = options[:subscription_type] || self.subscription_type
    base = "/search/#{subscription_type}"
    
    base << "/#{URI.encode data['query']}" if data['query']

    query_string = filters.map {|key, value| "#{subscription_type}[#{key}]=#{URI.encode value}"}.join("&")
    base << "?#{query_string}" if query_string.present?

    base
  end

  # convenience method - the 'data' field, but minus the 'query' field
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

  def filter_name(field, value)
    if adapter.respond_to?(:filters)
      adapter.filters[field.to_s][:name].call value
    else

    end
  end
  
  # what fields are acceptable to syndicated through JSON
  def self.public_json_fields
    [
      'created_at', 'data', 'last_checked_at', 'updated_at', 'subscription_type'
    ]
  end
end
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

  # the mechanism this subscription prefers to be delivered as (e.g. email or SMS).
  # for right now, reads right from the user's preferences, but could be changed
  # to be per-interest or per-subscription.
  def mechanism
    return nil unless user.notifications
    user.notifications =~ /email/ ? "email" : "sms"
  end

  def email_frequency
    return nil unless user.notifications

    if user.notifications =~ /immediate/ 
      "immediate"
    elsif user.notifications =~ /daily/
      "daily"
    end
  end


  # what fields are acceptable to syndicated through JSON
  def self.public_json_fields
    [
      'created_at', 'data', 'last_checked_at', 'updated_at', 'subscription_type'
    ]
  end
end
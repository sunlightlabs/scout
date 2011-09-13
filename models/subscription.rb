class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscription_type
  field :initialized, :type => Boolean, :default => false
  field :keyword
  field :last_checked_at, :type => Time
  
  # catch-all used for subscription adapter specific memo data
  field :memo, :type => Hash, :default => {}
    
  index :subscription_type
  index :initialized
  index :user_id
  index :keyword
  index :last_checked_at
  
  has_many :seen_ids
  has_many :deliveries
  belongs_to :user
  
  validates_presence_of :user_id
  validates_presence_of :subscription_type
  
  # will eventually refer to individual subscription type's validation method
  validate do
    if keyword.blank?
      errors.add(:base, "Enter a keyword or phrase to subscribe to.")
    end
  end
  
  scope :initialized, :where => {:initialized => true}
  scope :uninitialized, :where => {:initialized => false}
  
  # adapter class associated with a particular subscription
  def adapter
    "Subscriptions::Adapters::#{subscription_type.camelize}".constantize rescue nil
  end
  
  after_create :initialize_self
  def initialize_self
    Subscriptions::Manager.initialize! self
  end
end
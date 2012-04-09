# queue of to-be-delivered items
# designed to stay empty, inbox-zero style, with completed deliveries stored separately

class Delivery
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :subscription
  belongs_to :interest
  belongs_to :user
  
  field :subscription_id
  field :user_id
  field :interest_id
  
  # core fields needed to deliver the goods
  field :user_email
  field :subscription_type
  field :interest_in

  # store where this delivery should go out over email or sms
  # will probably be populated by user's settings, but the
  # delivery task should look at *this* field, so that we can
  # add the ability to override per-interest, per-subscription, whatever
  field :mechanism
  
  # item details
  field :item, :type => Hash, :default => {}
  
  index :subscription_type
  index :user_email
  
  validates_presence_of :subscription_id
  validates_presence_of :subscription_type
  validates_presence_of :interest_in
  validates_presence_of :user_id
  validates_presence_of :user_email
  validates_presence_of :item
end
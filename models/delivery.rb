# queue of to-be-delivered items

# designed to stay empty, inbox-zero style, with completed deliveries stored separately
# designed to not depend on joining with other tables
# designed to be extractable and potentially implemented elsewhere, e.g. as part of a separate queueing system

class Delivery
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :subscription
  
  # references to other tables, shouldn't be needed but useful for debugging and archival
  field :subscription_id
  field :user_id
  
  # core fields needed to deliver the goods
  field :user_email
  field :subscription_type
  field :subscription_keyword
  
  # item details
  field :item_id
  field :item_date, :type => Time
  field :item_data, :type => Hash, :default => {}
  
  index :subscription_type
  index :user_email
  
  validates_presence_of :subscription_id
  validates_presence_of :subscription_type
  validates_presence_of :subscription_keyword
  validates_presence_of :user_id
  validates_presence_of :user_email
  validates_presence_of :item_id
  validates_presence_of :item_date
  validates_presence_of :item_data
end
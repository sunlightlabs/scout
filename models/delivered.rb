# transaction log of delivered items

class Delivered
  include Mongoid::Document
  
  # references to other tables, shouldn't be needed but useful for debugging purposes
  field :subscription_id
  field :user_id
  field :seen_item_id
  
  # original fields as were delivered
  field :user_email
  field :subscription_type
  field :data, :type => Hash, :default => {}
  
  # delivery time
  field :delivered_at, :type => Time
  
  index :subscription_id
  index :user_id
  index :seen_item_id
  index :subscription_type
  index :delivered_at
  
  validates_presence_of :subscription_id
  validates_presence_of :subscription_type
  validates_presence_of :user_id
  validates_presence_of :user_email
  validates_presence_of :seen_item_id
  validates_presence_of :delivered_at
end
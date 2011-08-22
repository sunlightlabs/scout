# log of all seen items that have come through the system - will only store an item once per subscription-type, and accumulates over time

class SeenItem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscription_type
  field :item_id
  field :data, :type => Hash, :default => {}
  
  index :subscription_type
  index :item_id
end
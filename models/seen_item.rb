# historical log of all seen items that have come through the system
# will only store an item once per subscription-type, and accumulates over time

# should not need to be queried dynamically by users
# only queried regularly by the backend when deciding whether to store a new item

class SeenItem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscription_type
  field :item_id
  field :data, :type => Hash, :default => {}
  
  index :subscription_type
  index :item_id
end
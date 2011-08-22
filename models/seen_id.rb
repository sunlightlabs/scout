# All seen IDs, per-subscription
# Stores tiny records that serve to note when an item has already been seen by this subscription

class SeenId
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscription_id
  field :item_id
  
  index [
    [:subscription_id, Mongo::ASCENDING],
    [:item_id, Mongo::ASCENDING]
  ]
  
  validates_presence_of :subscription_id
  validates_presence_of :item_id
end
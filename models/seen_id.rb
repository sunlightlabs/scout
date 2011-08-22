class SeenId
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscription_id
  field :item_id
  
  index [
    [:subscription_id, Mongo::ASCENDING],
    [:item_id, Mongo::ASCENDING]
  ]
end
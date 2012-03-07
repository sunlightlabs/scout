# Stores full data on seen items
# Used to cache items and render them later if need be (e.g. RSS, SMS)

class SeenItem
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :subscription

  field :subscription_id
  field :subscription_type
  field :subscription_keyword

  field :keyword_id

  field :item_id
  field :item_data, :type => Hash
  field :item_date, :type => DateTime

  # fields inherited from item, if present

  # search URL that originally produced this item
  field :item_search_url
  # to look up full details on item, if supported
  field :item_url 


  index [
    [:subscription_id, Mongo::ASCENDING],
    [:item_id, Mongo::ASCENDING]
  ]

  validates_presence_of :subscription_id
  validates_presence_of :item_id
end
# Any item, seen or not. Not attached to a subscription, user, or interest.
#   currently only used to generate sitemaps.

class Item
  include Mongoid::Document
  include Mongoid::Timestamps

  # what kind of item this is. (bill, speech, etc.)
  field :item_type

  # unique ID for this item (unique within item_type)
  field :item_id

  # data (same as stored on seen items, and item interests)
  field :data, type: Hash, default: {}

  index item_id: 1
  index item_type: 1
  index created_at: 1
  index({item_type: 1, created_at: 1})

  validates_presence_of :item_type
  validates_presence_of :item_id

  # relevant subscription adapter
  def adapter
    Subscription.adapter_for(item_types[item_type]['adapter'])
  end

  def self.from_seen!(seen_item)
    item = Item.find_or_initialize_by(
      item_type: seen_item.item_type,
      item_id: seen_item.item_id
    )

    item.data = seen_item.data
    item.save!
  end
end
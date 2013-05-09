# Any item, seen or not. Not attached to a subscription, user, or interest.
#   currently only used to generate sitemaps.

class Item
  include Mongoid::Document
  include Mongoid::Timestamps

  # what kind of item this is. (bill, speech, etc.)
  field :item_type

  # unique ID for this item (unique within item_type)
  field :item_id

  field :date, type: Time # fine

  # data (same as stored on seen items, and item interests)
  field :data, type: Hash, default: {}

  field :google_hits, type: Array, default: []
  field :last_google_hit, type: Time

  index item_id: 1
  index item_type: 1
  index created_at: 1
  index({item_type: 1, created_at: 1})
  index google_hits: 1
  index last_google_hit: 1

  validates_presence_of :item_type
  validates_presence_of :item_id

  # relevant subscription adapter
  def adapter
    Subscription.adapter_for(item_types[item_type]['adapter'])
  end

  def self.from_seen!(seen_item)
    item = Item.find_or_initialize_by(
      item_type: seen_item.item_type,
      item_id: seen_item.item_id,
    )

    item.date = seen_item.date
    item.data = seen_item.data

    item.save!
  end

  # prepare a SeenItem, un-assigned to a subscription, as if it just came out
  # of an adapter (I know, this is weird - these models should get merged)
  # warning: lacking a date field, geez - another thing to refactor
  def self.to_seen!(item)
    SeenItem.new(
      item_id: item.item_id,
      item_type: item.item_type,
      date: item.date,
      data: item.data
    )
  end
end
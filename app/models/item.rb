# An item (which may or not have been seen) that is not attached to any
# interest or subscription.
#
# Pages are added to `sitemap.xml` for each item. Primes the cache with items
# from data sources.
class Item
  include Mongoid::Document
  include Mongoid::Timestamps

  # @return [String] the item's type, e.g. "bill"
  # @note There is a list of item types in `subscriptions/subscriptions.yml`
  field :item_type

  # @return [String] the item's unique identifier among items of the same type
  field :item_id

  # @return [Time] the time at which this item occurred, at which it was created
  #   or published, or another time of origin
  field :date, type: Time # fine

  # @return [Hash] arbitrary data
  # @note Seen items and "item" interests store identical data.
  field :data, type: Hash, default: {}

  index item_id: 1
  index item_type: 1
  index created_at: 1
  index({item_type: 1, created_at: 1})

  validates_presence_of :item_type
  validates_presence_of :item_id

  # @return [Class] the subscription adapter for this item
  def adapter
    Subscription.adapter_for(item_types[item_type]['adapter'])
  end

  # @param [SeenItem] a seen item
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
  # @param [Item] an item
  # @return [SeenItem] a seen item
  def self.to_seen!(item)
    SeenItem.new(
      item_id: item.item_id,
      item_type: item.item_type,
      date: item.date,
      data: item.data
    )
  end
end

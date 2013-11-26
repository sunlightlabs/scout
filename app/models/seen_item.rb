# An item that is attached to a subscription or interest. To avoid notifying a
# user about the same item twice within the same interest, we track which items
# are "seen", per-user and per-interest. It's possible that a user will see the
# same item twice across multiple interests. This is intentional, as different
# text may be highlighted in each notification: consider, for example, a long
# bill that touches on many different subjects.
class SeenItem
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :subscription
  belongs_to :interest
  belongs_to :user

  # @todo Refactor this out. It should be possible to derive subscriptions
  #   on-demand from the interest.
  # XXX redundant with `belongs_to :subscription`?
  field :subscription_id

  # @return [String] what the user is interested in (terms, feed URL, etc.)
  field :interest_in
  # @return [String] one of "feed", "item", "search" or "tag"
  field :interest_type
  # @return [String] the lowercase underscored name of the subscription's adapter
  field :subscription_type

  # @return [String] the item's type, e.g. "bill"
  # @note There is a list of item types in `subscriptions/subscriptions.yml`
  field :item_type

  # @return [String] the item's unique identifier among items of the same type
  field :item_id
  # @return [Hash] arbitrary data
  field :data, type: Hash
  # @return [Time] the time at which this item occurred, at which it was created
  #   or published, or another time of origin
  field :date, type: Time
  # @return [String] the URL to query the data source for items relevant to the
  #   subscription, which included this item
  field :search_url
  # @return [String] the URL to get this item from the data source, if this item
  #   originates from an API request for a single document
  field :find_url

  index({subscription_id: 1, item_id: 1})
  index item_id: 1
  index item_type: 1
  index subscription_type: 1
  index user_id: 1
  index seen_by_id: 1
  index created_at: 1
  index date: 1
  index interest_id: 1

  # used for lookups for RSS feeds
  index({interest_id: 1, date: 1})

  validates_presence_of :subscription_id
  validates_presence_of :item_id

  # the subset of fields appropriate for public syndication (omit database IDs, for instance)
  # @private
  def self.public_json_fields
    [
      'created_at', 'item_id', 'data', 'date', 'subscription_type'
    ]
  end

  # @return [Boolean] whether the interest is in search terms
  def search?
    interest_type == "search"
  end

  # @return [Boolean] whether the interest is in a feed
  def feed?
    interest_type == "feed"
  end

  # @return [Boolean] whether the interest is in an item
  def item?
    interest_type == "item"
  end

  # take a SeenItem right from an adapter and assign it a particular subscription
  def assign_to_subscription(subscription)

    # interest may not exist on the subscription, infer it from the subscription_type
    if subscription.subscription_type == "feed"
      item_type = "feed_item" # ?
      interest_type = "feed"
    elsif item_type = search_adapters[subscription.subscription_type]
      interest_type = "search"
    elsif item_type = item_adapters[subscription.subscription_type]
      interest_type = "item"
    end

    self.attributes = {
      # core fields
      subscription_type: subscription.subscription_type,
      item_type: item_type,
      interest_type: interest_type,
      interest_in: subscription.interest_in,

      # the interest and user may not exist yet on the subscription
      # TODO: refactor so that the interest is passed in and is always
      # guaranteed to exist (user still may not be)
      interest_id: subscription.interest_id,

      # TODO: refactor this out
      subscription: subscription,

      user_id: subscription.user_id
    }
  end

  # @private
  def self.clean_document(document, only = nil)
    attrs = document.attributes
    attrs.delete "_id"

    if only
      attrs.keys.each do |key|
        attrs.delete(key) unless only.include?(key)
      end
    end

    attrs
  end
end

# Stores full data on seen items
# Used to cache items and render them later if need be (e.g. RSS, SMS)

class SeenItem
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :subscription
  belongs_to :interest
  belongs_to :user

  #TODO: refactor this out
  field :subscription_id 

  field :interest_in
  field :interest_type
  field :subscription_type
  
  # doesn't refer to the type of the item itself, but 
  # rather which one of the standard item_type's it relates to
  field :item_type # 'bill', 'speech', etc.

  # result fields from remote source
  field :item_id
  field :data, type: Hash
  field :date, type: Time
  field :search_url # search URL that originally produced this item
  field :find_url # if this came from a find request, produce that URL

  index({subscription_id: 1, item_id: 1})
  index item_id: 1
  index subscription_type: 1
  index interest_id: 1
  index user_id: 1
  index seen_by_id: 1

  validates_presence_of :subscription_id
  validates_presence_of :item_id

  # the subset of fields appropriate for public syndication (omit database IDs, for instance)
  def self.public_json_fields
    [
      'created_at', 'item_id', 'data', 'date', 'subscription_type'
    ]
  end

  def search?
    interest_type == "search"
  end

  def feed?
    interest_type == "feed"
  end

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

  # renders a *hash* suitable for turning into json, 
  # that includes attributes for its parent subscription and interest
  def json_view
    self.interest

    SeenItem.clean_document(self, SeenItem.public_json_fields).merge(
      :interest => SeenItem.clean_document(self.interest, Interest.public_json_fields)
    )
  end


  # internal

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
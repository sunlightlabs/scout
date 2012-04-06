# Stores full data on seen items
# Used to cache items and render them later if need be (e.g. RSS, SMS)

class SeenItem
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :subscription
  belongs_to :interest
  belongs_to :user

  # origin subscription
  field :subscription_id
  field :subscription_type
  field :subscription_interest_in

  # reference by interest for interest-level feeds and landing page
  field :interest_id

  # reference by user for user-level feeds
  field :user_id

  # result fields from remote source
  field :item_id
  field :data, :type => Hash
  field :date, :type => Time
  field :search_url # search URL that originally produced this item
  field :find_url # if this came from a find request, produce that URL


  index [
    [:subscription_id, Mongo::ASCENDING],
    [:item_id, Mongo::ASCENDING]
  ]

  index :subscription_type

  validates_presence_of :subscription_id
  validates_presence_of :item_id

  def url
    if subscription.adapter.respond_to? :find_url
      subscription.adapter.find_url item_id, data
    end
  end

  # the subset of fields appropriate for public syndication (omit database IDs, for instance)
  def self.public_json_fields
    [
      'created_at', 'item_id', 'data', 'date', 'subscription_type'
    ]
  end

  # renders a *hash* suitable for turning into json, 
  # that includes attributes for its parent subscription and interest
  def json_view
    self.subscription # needed to get this to load??
    self.interest

    SeenItem.clean_document(self, SeenItem.public_json_fields).merge(
      :subscription => SeenItem.clean_document(self.subscription, Subscription.public_json_fields),
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
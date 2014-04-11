# An item in a queue of to-be-delivered items.
#
# The queue is designed to empty itself as items are delivered (like most MTAs)
# with successful deliveries stored separately as receipts.
class Delivery
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :interest
  belongs_to :user

  # @return [String] the lowercase underscored name of the subscription's adapter
  field :subscription_type
  # @return [String] what the user is interested in (terms, feed URL, etc.)
  field :interest_in

  # used for DEBUG/TESTING CONVENIENCE ONLY -
  # During actual delivery, the email to deliver this to
  # should be looked up AGAIN, in case the user's email has changed.
  # @return [String] the subscriber's email address
  field :user_email

  # Alice tags her interests, creating a collection. Bob is interested in
  # Alice's collection; his interest is modeled as an interest of type "tag"
  # pointing to the collection. Bob sees an item in one of Alice's collected
  # interests through his interest.
  #
  # For deliveries related to Bob's interest in Alice's collection, the `user`
  # is Bob, the `interest` is Alice's interest and `seen_through` is Bob's
  # interest.
  belongs_to :seen_through, class_name: "Interest"



  # the delivery task should look at *this* field, so that we can
  # add the ability to override per-interest, per-subscription, whatever
  # @return [String] the way in which to deliver the alert ("email")

  # TODO: kill this field
  field :mechanism

  # @return [Hash] a copy of the item's attributes
  field :item, :type => Hash, :default => {}

  index subscription_type: 1
  index user_email: 1
  index "item.date" => 1
  index "item.item_id" => 1
  index interest_id: 1
  index user_id: 1
  index seen_through_id: 1

  validates_presence_of :interest_id
  validates_presence_of :subscription_type
  validates_presence_of :interest_in
  validates_presence_of :user_id
  validates_presence_of :item

  # Schedules an item, from a data source, related to an interest, to be
  # delivered to a user via either email or SMS, either immediately or daily.
  #
  # @param [SeenItem] item the item to deliver
  # @param [Interest] interest the interest to which the item is related
  # @param [String] subscription_type the lowercase underscored name of the
  #   subscription's adapter
  # @param [Interest] seen_through "tag" interests see items through other
  #   user's interests
  # @param [User] user the user to deliver the item to
  # @param [String] "email"
  # @param [String] email_frequency either "daily" or "immediate"
  def self.schedule!(item, interest, subscription_type, seen_through, user, mechanism, email_frequency)
    create! user_id: user.id,

      # for convenience of debugging only - what these values were at schedule-time
      user_email: user.email,

      subscription_type: subscription_type,

      interest_in: interest.in,
      interest: interest,

      seen_through: seen_through,

      mechanism: mechanism,
      email_frequency: email_frequency,

      # drop the item into the delivery wholesale
      item: item.attributes.dup
  end
end

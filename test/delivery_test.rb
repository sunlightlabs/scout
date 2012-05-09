require './test/test_helper'

class DeliveryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods

  def test_schedule_delivery_with_user_defaults
    user = new_user!
    query = "copyright"

    interest = user.interests.create! :in => query, :interest_type => "search"
    subscription = user.subscriptions.create! :interest => interest, :subscription_type => "federal_bills", :interest_in => query

    item = SeenItem.new(
      :item_id => "hr2431-112",
      :date => Time.now,
      :data => {"bill_id" => "hr2431-112"}
    )
    item.assign_to_subscription subscription

    assert_equal 0, Delivery.count
    assert_equal nil, interest.notifications
    assert_equal "email_immediate", user.notifications
    assert_equal "email", interest.mechanism
    assert_equal "immediate", interest.email_frequency

    Deliveries::Manager.schedule_delivery! item

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal "email", delivery.mechanism
    assert_equal "immediate", delivery.email_frequency

    assert_equal interest.in, delivery.interest_in
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_schedule_delivery_with_interest_override
    user = new_user!
    query = "copyright"

    interest = user.interests.create! :in => query, :interest_type => "search", :notifications => "email_daily"
    subscription = user.subscriptions.create! :interest => interest, :subscription_type => "federal_bills", :interest_in => query

    item = SeenItem.new(
      :item_id => "hr2431-112",
      :date => Time.now,
      :data => {"bill_id" => "hr2431-112"}
    )
    item.assign_to_subscription subscription

    assert_equal 0, Delivery.count
    assert_equal "email_daily", interest.notifications
    assert_equal "email_immediate", user.notifications
    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    Deliveries::Manager.schedule_delivery! item

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal "email", delivery.mechanism
    assert_equal "daily", delivery.email_frequency

    assert_equal interest.in, delivery.interest_in
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_schedule_delivery_with_user_preference_of_none
    user = new_user! :notifications => "none"
    query = "copyright"

    interest = user.interests.create! :in => query, :interest_type => "search"
    subscription = user.subscriptions.create! :interest => interest, :subscription_type => "federal_bills", :interest_in => query

    item = SeenItem.new(
      :item_id => "hr2431-112",
      :date => Time.now,
      :data => {"bill_id" => "hr2431-112"}
    )
    item.assign_to_subscription subscription

    assert_equal 0, Delivery.count
    assert_equal nil, interest.notifications
    assert_equal "none", user.notifications
    assert_nil interest.mechanism

    # should *not* schedule the delivery (this should perhaps be rethought)
    Deliveries::Manager.schedule_delivery! item

    assert_equal 0, Delivery.count
  end

end
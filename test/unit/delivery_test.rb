require './test/test_helper'

class DeliveryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_schedule_delivery_with_user_defaults
    user = create :user
    query = "copyright"

    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

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
    user = create :user
    query = "copyright"

    interest = search_interest! user, "federal_bills", query, {}, :notifications => "email_daily"
    
    subscription = interest.subscriptions.first

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
    user = create :user, :notifications => "none"
    query = "copyright"

    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

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
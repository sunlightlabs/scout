require './test/test_helper'

class DeliveryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_schedule_delivery_with_user_defaults
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count
    assert_equal nil, interest.notifications
    assert_equal "email_immediate", user.notifications

    assert_equal "email", interest.mechanism
    assert_equal "immediate", interest.email_frequency

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal "email", delivery.mechanism
    assert_equal "immediate", delivery.email_frequency

    assert_equal interest.in, delivery.interest_in
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_schedule_delivery_with_interest_override
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query, {}, notifications: "email_daily"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count
    assert_equal "email_daily", interest.notifications
    assert_equal "email_immediate", user.notifications
    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal "email", delivery.mechanism
    assert_equal "daily", delivery.email_frequency

    assert_equal interest.in, delivery.interest_in
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_delivery_for_confirmed_user
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 1, Delivery.count
  end

   def test_delivery_for_user_with_preference_of_none_is_not_scheduled
    query = "environment"
    user = create :user, notifications: "none"
    interest = search_interest! user, "federal_bills", query, {}
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count
    assert_equal nil, interest.notifications
    assert_equal "none", user.notifications
    assert_nil interest.mechanism

    # should *not* schedule the delivery (this should perhaps be rethought)
    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 0, Delivery.count
  end

  def test_delivery_for_unconfirmed_user_is_not_scheduled
    query = "environment"
    user = create :user, :confirmed => false
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 0, Delivery.count
  end

  def test_sms_delivery_for_user_without_confirmed_phone_is_not_scheduled
  end

  def test_actual_delivery
  end

  def test_delivery_for_unconfirmed_user_is_not_delivered
  end

  def test_sms_delivery_for_user_without_confirmed_phone_is_not_delivered
  end

end
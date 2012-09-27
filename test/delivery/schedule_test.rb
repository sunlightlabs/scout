require './test/test_helper'

class ScheduleTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_schedule_delivery
    query = "environment"
    user = create :user
    search_type = "federal_bills"
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal interest.id, delivery.interest_id
    assert_equal interest.in, delivery.interest_in
    assert_equal user.id, delivery.user_id
    assert_equal user.email, delivery.user_email
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_schedule_delivery_with_user_defaults
    query = "environment"
    user = create :user
    search_type = "federal_bills"
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count
    assert_equal nil, interest.notifications
    assert_equal "email_immediate", user.notifications

    assert_equal "email", interest.mechanism
    assert_equal "immediate", interest.email_frequency

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal "email", delivery.mechanism
    assert_equal "immediate", delivery.email_frequency

    assert_equal interest.in, delivery.interest_in
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_schedule_delivery_with_interest_override
    query = "environment"
    search_type = "federal_bills"
    user = create :user
    interest = search_interest! user, search_type, query, "simple", {}, notifications: "email_daily"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count
    assert_equal "email_daily", interest.notifications
    assert_equal "email_immediate", user.notifications
    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal "email", delivery.mechanism
    assert_equal "daily", delivery.email_frequency

    assert_equal interest.in, delivery.interest_in
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

  def test_delivery_for_confirmed_user
    query = "environment"
    search_type = "federal_bills"
    user = create :user
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 1, Delivery.count
  end

   def test_delivery_for_user_with_preference_of_none_is_not_scheduled
    query = "environment"
    search_type = "federal_bills"
    user = create :user, notifications: "none"
    interest = search_interest! user, search_type, query, "simple", {}
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count
    assert_equal nil, interest.notifications
    assert_equal "none", user.notifications
    assert_nil interest.mechanism

    # perhaps this method should not be called when the user's preference is is "none"
    # though it is much easier to do this wherever the rest of the checks lives
    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 0, Delivery.count
  end

  def test_delivery_for_unconfirmed_user_is_not_scheduled
    query = "environment"
    search_type = "federal_bills"
    user = create :user, :confirmed => false
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 0, Delivery.count
  end

  def test_sms_delivery_for_user_without_phone_is_not_scheduled
    query = "environment"
    search_type = "federal_bills"
    user = create :user, phone_confirmed: true, confirmed: true
    interest = search_interest! user, search_type, query, "simple", {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    assert user.confirmed?
    assert user.phone.blank?
    assert user.phone_confirmed?

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 0, Delivery.count
  end

  def test_sms_delivery_for_user_with_unconfirmed_phone_is_not_scheduled
    query = "environment"
    search_type = "federal_bills"
    phone = "+15555551212"
    user = create :user, phone: phone, phone_confirmed: false, confirmed: true
    interest = search_interest! user, search_type, query, "simple", {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    assert user.confirmed?
    assert user.phone.present?
    assert !user.phone_confirmed?

    Deliveries::Manager.schedule_delivery! items.first, interest, search_type

    assert_equal 0, Delivery.count
  end
end
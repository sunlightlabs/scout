require './test/test_helper'

class DeliveryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_schedule_delivery
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 1, Delivery.count
    delivery = Delivery.first

    assert_equal subscription.id, delivery.subscription_id
    assert_equal interest.id, delivery.interest_id
    assert_equal interest.in, delivery.interest_in
    assert_equal user.id, delivery.user_id
    assert_equal user.email, delivery.user_email
    assert_equal subscription.subscription_type, delivery.subscription_type
  end

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

  def test_sms_delivery_for_user_without_phone_is_not_scheduled
    query = "environment"
    user = create :user, phone_confirmed: true, confirmed: true
    interest = search_interest! user, "federal_bills", query, {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    assert user.confirmed?
    assert user.phone.blank?
    assert user.phone_confirmed?

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 0, Delivery.count
  end

  def test_sms_delivery_for_user_with_unconfirmed_phone_is_not_scheduled
    query = "environment"
    phone = "+15555551212"
    user = create :user, phone: phone, phone_confirmed: false, confirmed: true
    interest = search_interest! user, "federal_bills", query, {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 0, Delivery.count

    assert user.confirmed?
    assert user.phone.present?
    assert !user.phone_confirmed?

    Deliveries::Manager.schedule_delivery! items.first

    assert_equal 0, Delivery.count
  end

  def test_delivery
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    Delivery.schedule! user, subscription, items.first, interest.mechanism, interest.email_frequency

    assert_equal 0, Receipt.count

    Deliveries::Manager.deliver! 'mechanism' => interest.mechanism, 'email_frequency' => interest.email_frequency

    assert_equal 1, Receipt.count
  end

  def test_delivery_for_unconfirmed_user_is_not_delivered
    query = "environment"
    user = create :user, confirmed: false
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    Delivery.schedule! user, subscription, items.first, interest.mechanism, interest.email_frequency

    assert_equal 0, Receipt.count
    Deliveries::Email.should_not_receive :deliver_for_user!
    Deliveries::SMS.should_not_receive :deliver_for_user!

    Deliveries::Manager.deliver! 'mechanism' => interest.mechanism, 'email_frequency' => interest.email_frequency

    assert_equal 0, Receipt.count
  end

  def test_sms_delivery_for_user_without_phone_is_not_delivered
    query = "environment"
    user = create :user, phone_confirmed: true
    interest = search_interest! user, "federal_bills", query, {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    delivery = Delivery.schedule! user, subscription, items.first, interest.mechanism, interest.email_frequency

    assert_equal "sms", delivery.mechanism
    assert user.phone.blank?
    assert user.phone_confirmed?

    assert_equal 0, Receipt.count
    Deliveries::SMS.should_not_receive :sms_user

    Deliveries::SMS.deliver_for_user! user

    assert_equal 0, Receipt.count
  end

  def test_sms_delivery_for_user_without_confirmed_phone_is_not_delivered
    query = "environment"
    phone = "+15555551212"
    user = create :user, phone: phone, phone_confirmed: false
    interest = search_interest! user, "federal_bills", query, {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    delivery = Delivery.schedule! user, subscription, items.first, interest.mechanism, interest.email_frequency

    assert_equal "sms", delivery.mechanism
    assert user.phone.present?
    assert !user.phone_confirmed?

    assert_equal 0, Receipt.count
    Deliveries::SMS.should_not_receive :sms_user

    Deliveries::SMS.deliver_for_user! user

    assert_equal 0, Receipt.count
  end

end
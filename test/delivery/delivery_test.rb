require './test/test_helper'

class DeliveryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_deliver_one_interest_email_immediate
    # we have fixtures for this
    query = "environment"
    search_type = "federal_bills"

    user = create :user, notifications: "email_immediate"
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # schedule a delivery for each result
    items.each do |item|
      Deliveries::Manager.schedule_delivery! item, interest, search_type
    end
    assert_equal items.size, Delivery.count

    assert_equal 0, Receipt.count

    Deliveries::Manager.deliver! 'mechanism' => "email", 'email_frequency' => "immediate"

    assert_equal 0, Delivery.count
    assert_equal 1, Receipt.count
    receipt = Receipt.first

    assert_equal "email", receipt.mechanism
    assert_equal "immediate", receipt.email_frequency
    assert_equal user.id, receipt.user_id
    assert_equal user.email, receipt.user_email
    assert_equal items.size, receipt.deliveries.size
    assert_equal items.map(&:item_id), receipt.deliveries.map {|d| d['item']['item_id']}

    assert_match /#{items.size}/, receipt.subject
    items.each do |item|
      assert_not_nil receipt.content[routing.item_url item]
    end
  end

  def test_deliver_multiple_interests_email_immediate
    user = create :user, notifications: "email_immediate"

    # 3 different fixture'd searches
    # should be sent in 3 separate emails

    i1 = search_interest! user, "federal_bills", "environment", "simple"
    i2 = search_interest! user, "state_bills", "environment", "simple"
    i3 = search_interest! user, "state_bills", "science", "simple"
    
    all_items = {}
    # schedule a delivery for every result from every one
    [i1, i2, i3].each do |interest|
      # recalculate, should be cheap
      subscription = interest.subscriptions.first
      mock_search subscription
      all_items[interest.id] = subscription.search

      all_items[interest.id].each do |item|
        Deliveries::Manager.schedule_delivery! item, interest, interest.search_type
      end

      assert_equal all_items[interest.id].size, interest.deliveries.count
    end

    assert_equal 0, Receipt.count

    Deliveries::Manager.deliver! 'mechanism' => "email", 'email_frequency' => "immediate"
    assert_equal 0, Delivery.count
    assert_equal 3, Receipt.count
    
    Receipt.all.each do |receipt|
      item = receipt.deliveries.first['item']
      interest = Interest.find item['interest_id']
      items = all_items[interest.id]
      
      assert_equal "email", receipt.mechanism
      assert_equal "immediate", receipt.email_frequency
      assert_equal user.id, receipt.user_id
      assert_equal user.email, receipt.user_email

      assert_equal items.size, receipt.deliveries.size
      assert_equal items.map(&:item_id), receipt.deliveries.map {|d| d['item']['item_id']}

      assert_match /#{items.size}/, receipt.subject
      items.each do |item|
        assert_not_nil receipt.content[routing.item_url item]
      end
    end
  end

  def test_deliver_one_interest_email_daily
    #TODO
  end

  def test_deliver_multiple_interests_email_daily
    #TODO
  end

  def test_deliver_email_immediate_from_anothers_tag
    #TODO
  end

  def test_deliver_email_daily_from_anothers_tag
    #TODO
  end

  def test_deliver_sms
    #TODO
  end

  def test_deliver_sms_from_anothers_tag
    #TODO
  end


  # flood checking checking

  def test_flood_check
    query = "environment"
    search_type = "federal_bills"

    user = create :user, notifications: "email_immediate"
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # schedule 30 times the usual deliveries for each result
    30.times do
      items.each do |item|
        Deliveries::Manager.schedule_delivery! item, interest, search_type
      end
    end

    assert_equal (30 * items.size), Delivery.count

    assert_equal 0, Receipt.count
    Deliveries::Email.should_not_receive :deliver_for_user!
    Deliveries::SMS.should_not_receive :deliver_for_user!

    Deliveries::Manager.deliver! 'mechanism' => interest.mechanism, 'email_frequency' => interest.email_frequency

    assert_equal 0, Receipt.count

    report = Report.where(source: /flood/i).first
    assert_not_nil report
  end


  # final checks on inappropriate deliveries, done at schedule-time and delivery-time

  def test_delivery_for_unconfirmed_user_is_not_delivered
    query = "environment"
    search_type = "federal_bills"
    user = create :user, confirmed: false
    interest = search_interest! user, search_type, query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    Delivery.schedule! items.first, interest, search_type, interest, user, interest.mechanism, interest.email_frequency

    assert_equal 0, Receipt.count
    Deliveries::Email.should_not_receive :deliver_for_user!
    Deliveries::SMS.should_not_receive :deliver_for_user!

    Deliveries::Manager.deliver! 'mechanism' => interest.mechanism, 'email_frequency' => interest.email_frequency

    assert_equal 0, Receipt.count
  end

  def test_sms_delivery_for_user_without_phone_is_not_delivered
    query = "environment"
    search_type = "federal_bills"
    user = create :user, phone_confirmed: true
    interest = search_interest! user, search_type, query, "simple", {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    delivery = Delivery.schedule! items.first, interest, search_type, interest, user, interest.mechanism, interest.email_frequency

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
    search_type = "federal_bills"
    phone = "+15555551212"
    user = create :user, phone: phone, phone_confirmed: false
    interest = search_interest! user, search_type, query, "simple", {}, notifications: "sms"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    # force delivery to be scheduled of the item, this would not normally be done
    delivery = Delivery.schedule! items.first, interest, search_type, interest, user, interest.mechanism, interest.email_frequency

    assert_equal "sms", delivery.mechanism
    assert user.phone.present?
    assert !user.phone_confirmed?

    assert_equal 0, Receipt.count
    Deliveries::SMS.should_not_receive :sms_user

    Deliveries::SMS.deliver_for_user! user

    assert_equal 0, Receipt.count
  end

end
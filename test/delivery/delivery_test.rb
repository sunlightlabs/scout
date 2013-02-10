require './test/test_helper'

class DeliveryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_deliver_one_interest_email_immediate
    user = create :user, notifications: "email_immediate"
    
    # one fixture, one email

    interest = search_interest! user, "state_bills", "science_transition", "simple"
    assert_equal 3, interest.seen_items.count

    Subscriptions::Manager.check! interest.subscriptions.first
    assert_equal 6, interest.seen_items.count

    # 3 items in check that weren't present on initialize
    items = interest.seen_items.asc(:_id).to_a[3..-1]
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
    assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort

    assert_match /#{items.size}/, receipt.subject
    assert_not_match /Daily digest/i, receipt.subject
    items.each do |item|
      assert_not_nil receipt.content[routing.item_url item]
    end
  end

  def test_deliver_one_interest_email_daily
    user = create :user, notifications: "email_daily"
    
    # one fixture, one email

    interest = search_interest! user, "state_bills", "science_transition", "simple"
    assert_equal 3, interest.seen_items.count

    Subscriptions::Manager.check! interest.subscriptions.first
    assert_equal 6, interest.seen_items.count

    # 3 items in check that weren't present on initialize
    items = interest.seen_items.asc(:_id).to_a[3..-1]
    assert_equal items.size, Delivery.count

    assert_equal 0, Receipt.count

    Deliveries::Manager.deliver! 'mechanism' => "email", 'email_frequency' => "daily"

    assert_equal 0, Delivery.count
    assert_equal 1, Receipt.count
    receipt = Receipt.first

    assert_equal "email", receipt.mechanism
    assert_equal "daily", receipt.email_frequency
    assert_equal user.id, receipt.user_id
    assert_equal user.email, receipt.user_email
    
    assert_equal items.size, receipt.deliveries.size
    assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort

    assert_match /#{items.size}/, receipt.subject
    assert_match /Daily digest/i, receipt.subject
    items.each do |item|
      assert_not_nil receipt.content[routing.item_url item]
    end
  end

  def test_deliver_multiple_interests_email_immediate
    user = create :user, notifications: "email_immediate"

    # 3 different fixture'd searches
    # should be sent in 3 separate emails

    # 1 new one
    i1 = search_interest! user, "federal_bills", "environment", "simple"

    # 3 new ones each
    i2 = search_interest! user, "state_bills", "conscience", "simple"
    i3 = search_interest! user, "state_bills", "science", "simple"
    
    all_items = {}
    # schedule a delivery for every result from every one
    [i1, i2, i3].each do |interest|
      initial = interest.seen_items.count
      Subscriptions::Manager.check! interest.subscriptions.first
      all_items[interest.id] = interest.seen_items.asc(:_id).to_a[initial..-1]
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
      assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort

      assert_match /#{items.size}/, receipt.subject
      items.each do |item|
        assert_not_nil receipt.content[routing.item_url item]
      end
    end
  end

  def test_deliver_multiple_interests_email_daily
    user = create :user, notifications: "email_daily"

    # 3 different fixture'd searches
    # should be sent in 1 digest emails

    # 1 new one
    i1 = search_interest! user, "federal_bills", "environment", "simple"

    # 3 new ones each
    i2 = search_interest! user, "state_bills", "conscience", "simple"
    i3 = search_interest! user, "state_bills", "science", "simple"
    
    all_items = {}
    # schedule a delivery for every result from every one
    [i1, i2, i3].each do |interest|
      initial = interest.seen_items.count
      Subscriptions::Manager.check! interest.subscriptions.first
      all_items[interest.id] = interest.seen_items.asc(:_id).to_a[initial..-1]
      assert_equal all_items[interest.id].size, interest.deliveries.count
    end

    assert_equal 0, Receipt.count

    Deliveries::Manager.deliver! 'mechanism' => "email", 'email_frequency' => "daily"
    assert_equal 0, Delivery.count
    assert_equal 1, Receipt.count
    
    receipt = Receipt.first

    assert_equal "email", receipt.mechanism
    assert_equal "daily", receipt.email_frequency
    assert_equal user.id, receipt.user_id
    assert_equal user.email, receipt.user_email

    items = all_items.values.flatten
    assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort

    assert_match /#{items.size}/, receipt.subject
    assert_match /Daily digest/i, receipt.subject
    items.each do |item|
      assert_not_nil receipt.content[routing.item_url item]
    end
  end

  def test_deliver_custom_digest_to_multiple_users
  end

  def test_normal_complicated_situation
    # 3 users: one is immediate, one is daily, one is daily but has immediate overrides
    user1 = create :user, notifications: "email_immediate"
    user2 = create :user, notifications: "email_daily"
    user3 = create :user, notifications: "email_daily"

    # all 3 users should receive one custom email for all new deliveries,
    # with a specific subject and specific header

    # a = 1 old, 1 new thing, b and c = 3 old things, 3 new things each

    i1a = search_interest! user1, "federal_bills", "environment", "simple"
    i1b = search_interest! user1, "state_bills", "environment_transition", "simple"
    i1c = search_interest! user1, "state_bills", "science_transition", "simple"

    i2a = search_interest! user2, "federal_bills", "environment", "simple"
    i2b = search_interest! user2, "state_bills", "environment_transition", "simple"
    i2c = search_interest! user2, "state_bills", "science_transition", "simple"

    i3a = search_interest! user3, "federal_bills", "environment", "simple", {}, {notifications: "email_immediate"}
    i3b = search_interest! user3, "state_bills", "environment_transition", "simple", {}, {notifications: "email_immediate"}
    i3c = search_interest! user3, "state_bills", "science_transition", "simple"

    [user1, user2, user3].each do |u|
      assert_equal 7, u.seen_items.count
      assert_equal 0, u.deliveries.count
    end

    all_items = {}
    [i1a, i1b, i1c, i2a, i2b, i2c, i3a, i3b, i3c].each do |i| 
      initial = i.seen_items.count
      Subscriptions::Manager.check! i.subscriptions.first
      all_items[i.id] = i.seen_items.asc(:_id).to_a[initial..-1]
    end

    [user1, user2, user3].each do |u|
      assert_equal 14, u.seen_items.to_a.size
      assert_equal 7, u.deliveries.count
    end

    count = Delivery.count

    # deliver all 7 of user2's things, and 3 of user3's things
    assert_equal 0, Receipt.count
    Deliveries::Manager.deliver! 'mechanism' => "email", 'email_frequency' => "daily"
    assert_equal count - 10, Delivery.count
    assert_equal 2, Receipt.count

    receipt = user2.receipts.first
    items = all_items[i2a.id] + all_items[i2b.id] + all_items[i2c.id]
    assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort

    receipt = user3.receipts.first
    items = all_items[i3c.id]
    assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort

    # deliver all 7 of user1's things (3 interests), and 4 of user3's things (2 interests)
    Deliveries::Manager.deliver! 'mechanism' => "email", 'email_frequency' => "immediate"
    assert_equal 7, Receipt.count # 5 more

    user1.receipts.each do |receipt|
      item = receipt.deliveries.first['item']
      interest = Interest.find item['interest_id']
      items = all_items[interest.id]
      assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort
    end

    receipt = user3.receipts.where(frequency: "immediate").each do |receipt|
      item = receipt.deliveries.first['item']
      interest = Interest.find item['interest_id']
      items = all_items[interest.id]
      assert_equal items.size, receipt.deliveries.size
      assert_equal items.map(&:item_id).sort, receipt.deliveries.map {|d| d['item']['item_id']}.sort
    end
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
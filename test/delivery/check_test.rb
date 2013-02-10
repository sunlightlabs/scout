require './test/test_helper'

class CheckTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_poll_subscription
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query, "simple"
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 2, items.size
    items.each do |item|
      assert_equal query, item.interest_in
      assert_equal subscription, item.subscription # even with no id
      assert_equal subscription.subscription_type, item.subscription_type
      assert_equal interest.interest_type, item.interest_type
      assert_equal "bill", item.item_type
    end
  end

  def test_user_gets_deliveries_scheduled_upon_check
    # we have a fixture for this
    query = "environment" 
    search_type = "federal_bills"

    user = create :user, notifications: "email_immediate"
    interest = search_interest! user, search_type, query, "simple"
    assert_equal 1, interest.seen_items.count
    
    # check for new items (fixture has 1 new one on check)
    subscription = interest.subscriptions.first
    bill_id = "s3241-112" # is in fixtures
    
    count = Delivery.count

    Subscriptions::Manager.check! subscription

    assert_equal 2, interest.seen_items.count
    assert_equal 1, Delivery.count
    assert_equal 1, user.deliveries.where(interest_id: interest.id).count
    assert_not_nil user.deliveries.where(interest_id: interest.id, "item.item_id" => bill_id)

    user.deliveries.where(interest_id: interest.id).each do |delivery|
      assert_equal user, delivery.user
      assert_equal interest, delivery.interest
      assert_equal interest, delivery.seen_through
      assert_equal search_type, delivery.subscription_type
      assert_equal query, delivery.interest_in
    end
  end

  def test_user_following_tag_gets_deliveries_scheduled_as_well
    # we have a fixture for this
    query = "environment" 
    search_type = "federal_bills"

    sharing = create :user, notifications: "email_immediate"
    tag = create :public_tag, user: sharing
    shared_interest = search_interest! sharing, search_type, query, "simple", {}, tags: [tag.name]
    
    # should initialize subscription to an empty array, need to refactor this to allow 
    # mocking more easily before this step, and remove this
    assert_equal 1, shared_interest.seen_items.count

    user = create :user, notifications: "email_daily"
    tag_interest = Interest.for_tag(user, sharing, tag)
    tag_interest.save!

    
    # conditions are good?

    assert tag.public?
    assert tag.interests.include?(shared_interest)
    assert_equal tag_interest, user.interests.where(in: tag.id.to_s).first

    followers = shared_interest.followers
    assert_equal 1, followers.size
    assert followers.include?(tag_interest)


    # check for new items (fixture has 2)
    subscription = shared_interest.subscriptions.first
    bill_id = "hres727-112" # is in fixtures
    
    Subscriptions::Manager.check! subscription

    assert_equal 2, shared_interest.seen_items.count
    assert_equal 0, tag_interest.seen_items.count
    

    # now see that the deliveries were duplicated

    assert_equal 1, sharing.deliveries.count
    assert_equal 1, user.deliveries.count

    original_delivery = sharing.deliveries.where("item.item_id" => bill_id).first
    tag_delivery = user.deliveries.where("item.item_id" => bill_id).first
    assert_not_nil original_delivery
    assert_not_nil tag_delivery

    assert_equal sharing, original_delivery.user
    assert_equal shared_interest, original_delivery.interest
    assert_equal shared_interest, original_delivery.seen_through
    assert_equal query, original_delivery.interest_in
    assert_equal search_type, original_delivery.subscription_type
    assert_equal "email", original_delivery.mechanism
    assert_equal "immediate", original_delivery.email_frequency

    assert_equal user, tag_delivery.user
    assert_equal shared_interest, tag_delivery.interest
    assert_equal tag_interest, tag_delivery.seen_through
    assert_equal query, tag_delivery.interest_in
    assert_equal search_type, tag_delivery.subscription_type
    assert_equal "email", tag_delivery.mechanism
    assert_equal "daily", tag_delivery.email_frequency
  end

end
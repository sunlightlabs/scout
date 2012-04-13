require 'test/test_helper'

class SubscriptionsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods


  # subscribing to new things -
  # identical parameters to search, it should be easy to get a one to one mapping
  # between the two, and to lookup whether a search has already been subscribed to
  def test_subscribe_to_searches_by_plain_keyword
    # subscribe to search 1 with keyword A, verify new interest created
    # subscribe to search 2 with keyword A, verify same interest was updated
    # subscribe to search 3 with keyword B, verify new interest created
  end

  def test_subscribe_to_searches_with_accompanying_data
    # subscribe to search 1 with keyword A, data I, verify new interest created
    # subscribe to search 2 with keyword A, data II, verify same interest updated
    # subscribe to search 3 with keyword B, data I, verify new interest created
  end

  def test_unsubscribe_from_individual_searches
    # interest 1 has subscription 1 and subscription 2
    # interest 2 has subscription 1
    # unsubscribe from interest 1, subscription 1, verify interest 1 is intact
    # unsubscribe from interest 1, subscription 2, verify interest 1 is gone
    # unsubscribe from interest 2, subscription 1, verify interest 2 is gone
  end

  # Eventually: tests on subscriptions with no keyword at all

  def test_follow_item
    # subscribe to item 1, verify new interest created with all subscriptions
  end

  def test_unfollow_item
    # subscribe to item 1
    # unsubscribe from item 1, verify interest destroyed, along with all subscriptions
  end

  # tragic
  def test_destroy_search_interest
    Subscriptions::Manager.stub(:initialize!)

    user = new_user!
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query
    s2 = interest.subscriptions.create! :subscription_type => "state_bills", :user_id => user.id, :interest_in => query

    delete "/interest/#{interest.id}", {}, login(user)
    assert_equal 200, last_response.status

    assert_nil Interest.find(interest.id)
    assert_nil Subscription.find(s1.id)
    assert_nil Subscription.find(s2.id)
  end

  def test_destroy_search_interest_not_users_own
  end

  def test_destroy_search_interest_not_logged_in
  end

  def test_update_interest_delivery_type
  end

  def test_update_interest_not_users_own
  end

  def test_update_interest_not_logged_in
  end

end
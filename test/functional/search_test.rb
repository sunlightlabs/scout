require './test/test_helper'

class SearchTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_subscribe_to_searches_by_plain_keyword
    user = create :user
    query = "environment"
    query2 = "copyright"
    
    assert_equal 0, user.subscriptions.count
    assert_equal 0, user.interests.count


    post "/interests/search", {:search_type => "federal_bills", :query => query}, login(user)
    assert_response 200

    assert_equal 1, user.subscriptions.count
    assert_equal 1, user.interests.count

    interest1 = user.interests.where(:in => query).first
    assert_not_nil interest1

    subscription1 = interest1.subscriptions.first
    assert_equal "federal_bills", subscription1.subscription_type


    post "/interests/search", {search_type: "state_bills", query: query}, login(user)
    assert_response 200

    criteria = user.subscriptions.where(:subscription_type => "state_bills", :interest_in => query)
    assert_equal 1, criteria.count
    subscription2 = criteria.first
    interest2 = subscription2.interest

    assert_not_equal interest1, interest2

    assert_equal 2, user.subscriptions.count
    assert_equal 2, user.interests.where(:in => query).count
    assert_equal 1, interest2.subscriptions.count
    assert_equal 1, interest1.reload.subscriptions.count


    post "/interests/search", {:search_type => "state_bills", :query => query2}, login(user)
    assert_response 200

    assert_equal 3, user.subscriptions.count
    assert_equal 3, user.interests.count

    criteria = user.subscriptions.where(:subscription_type => "state_bills", :interest_in => query2)
    assert_equal 1, criteria.count
    subscription3 = criteria.first
    interest3 = subscription3.interest
    assert_equal 1, interest3.subscriptions.count
    assert_equal 1, interest2.reload.subscriptions.count
    

    # posting the same subscription should return 200, but be idempotent - nothing changed
    post "/interests/search", {:search_type => "state_bills", :query => query2}, login(user)
    assert_response 200

    assert_equal 3, user.subscriptions.count
    assert_equal 3, user.interests.count


    # but if we include filter data, it's different!
    post "/interests/search", {:search_type => "state_bills", :query => query2, :state_bills => {:state => "DE"}}, login(user)
    assert_response 200

    assert_equal 4, user.subscriptions.count
    assert_equal 4, user.interests.count

    assert_equal 2, user.subscriptions.where(:subscription_type => "state_bills", :interest_in => query2).count
    criteria = user.subscriptions.where(:subscription_type => "state_bills", :interest_in => query2, "data.state" => "DE")
    assert_equal 1, criteria.count
    subscription4 = criteria.first
    interest4 = subscription4.interest

    assert_equal 1, interest4.subscriptions.count

    # but, that data is also taken into account when finding duplicates
    post "/interests/search", {:search_type => "state_bills", :query => query2, :state_bills => {:state => "DE"}}, login(user)
    assert_response 200

    assert_equal 4, user.subscriptions.count
    assert_equal 4, user.interests.count
  end

  def test_subscribe_to_all_types_with_one_keyword
    user = create :user
    query = "environment"
    query2 = "copyright"
    
    assert_equal 0, user.subscriptions.count
    assert_equal 0, user.interests.count

    post "/interests/search", {:search_type => "all", :query => query}, login(user)
    assert_response 200

    assert_equal search_types.size, user.subscriptions.count
    assert_equal 1, user.interests.count

    interest1 = user.interests.where(:in => query).first
    assert_not_nil interest1
    assert_equal search_types.size, interest1.subscriptions.count

    interest1.subscriptions.each do |subscription|
        assert_equal query, subscription.interest_in
    end


    post "/interests/search", {:search_type => "all", :query => query2}, login(user)
    assert_response 200

    assert_equal search_types.size * 2, user.subscriptions.count
    assert_equal 2, user.interests.count

    interest2 = user.interests.where(:in => query2).first
    assert_not_nil interest2
    assert_equal search_types.size, interest2.subscriptions.count
    

    post "/interests/search", {:search_type => "all", :query => query2}, login(user)
    assert_response 200

    assert_equal search_types.size * 2, user.subscriptions.count
    assert_equal 2, user.interests.count
  end

  def test_subscribe_decodes_query
    user = create :user
    query_encoded = "sunlight%20foundation"
    query_decoded = "sunlight foundation"
    
    assert_equal 0, user.subscriptions.count
    assert_equal 0, user.interests.count

    post "/interests/search", {:search_type => "federal_bills", :query => query_encoded}, login(user)
    assert_response 200

    assert_equal 1, user.subscriptions.count
    assert_equal 1, user.interests.count

    assert_equal query_decoded, user.subscriptions.first.interest_in
    assert_equal query_decoded, user.interests.first.in

    # should have it decoded by the dupe detection step
    post "/interests/search", {:search_type => "federal_bills", :query => query_decoded}, login(user)
    assert_response 200

    assert_equal 1, user.subscriptions.count
    assert_equal 1, user.interests.count
  end


  # unsubscribing

  def test_unsubscribe_from_individual_searches
    user = create :user
    query1 = "environment"
    query2 = "guns"
    i1 = search_interest! user, "state_bills", query1, "simple"
    i2 = search_interest! user, "state_bills", query2, "simple", {'state' => "CA"}

    delete "/interests/search", {:search_type => i1.search_type, :query => i1.in}, login(user)
    assert_response 200

    assert_nil Interest.find(i1.id)
    
    delete "/interests/search", {:search_type => i2.search_type, :query => i2.in, i2.search_type => {'state' => 'DE'}}, login(user)
    assert_response 404

    assert_not_nil Interest.find(i2.id)
    
    delete "/interests/search", {:search_type => i2.search_type, :query => i2.in, i2.search_type => {'state' => "CA"}}, login(user)
    assert_response 200

    assert_nil Interest.find(i2.id)
  end

  def test_unsubscribe_to_type_of_all
    user = create :user
    query = "environment"
    interest = search_interest! user, "all", query, "simple"
    
    delete "/interests/search", {:search_type => "all", :query => interest.in}, login(user)
    assert_response 200

    assert_nil Interest.find(interest.id)
  end
end
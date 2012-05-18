require './test/test_helper'

class SearchTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  # subscribing to new things

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


    post "/interests/search", {:search_type => "state_bills", :query => query}, login(user)
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

    assert_equal search_adapters.keys.size, user.subscriptions.count
    assert_equal 1, user.interests.count

    interest1 = user.interests.where(:in => query).first
    assert_not_nil interest1
    assert_equal search_adapters.keys.size, interest1.subscriptions.count

    interest1.subscriptions.each do |subscription|
        assert_equal query, subscription.interest_in
    end


    post "/interests/search", {:search_type => "all", :query => query2}, login(user)
    assert_response 200

    assert_equal search_adapters.keys.size * 2, user.subscriptions.count
    assert_equal 2, user.interests.count

    interest2 = user.interests.where(:in => query2).first
    assert_not_nil interest2
    assert_equal search_adapters.keys.size, interest2.subscriptions.count
    

    post "/interests/search", {:search_type => "all", :query => query2}, login(user)
    assert_response 200

    assert_equal search_adapters.keys.size * 2, user.subscriptions.count
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
    i1 = create :search_interest, :user => user, :in => query1, :search_type => "state_bills"
    i2 = create :search_interest, :user => user, :in => query2, :search_type => "state_bills", :data => {"query" => query2, 'state' => "CA"}
    s1 = create :search_subscription, :user => user, :interest => i1, :subscription_type => "state_bills"
    s2 = create :search_subscription, :user => user, :interest => i2, :subscription_type => "state_bills"

    assert_equal i2.data['state'], s2.data['state']

    delete "/interests/search", {:search_type => i1.search_type, :query => i1.in}, login(user)
    assert_response 200

    assert_nil Interest.find(i1.id)
    assert_nil Subscription.find(s1.id)

    delete "/interests/search", {:search_type => i2.search_type, :query => i2.in, i2.search_type => {'state' => 'DE'}}, login(user)
    assert_response 404

    assert_not_nil Interest.find(i2.id)
    assert_not_nil Subscription.find(s2.id)

    delete "/interests/search", {:search_type => i2.search_type, :query => i2.in, i2.search_type => {'state' => "CA"}}, login(user)
    assert_response 200

    assert_nil Interest.find(i2.id)
    assert_nil Subscription.find(s2.id)
  end

  def test_unsubscribe_to_type_of_all
    user = create :user
    query1 = "environment"
    i1 = create :search_interest, :user => user, :in => query1, :search_type => "all"
    s1 = create :subscription, :interest => i1, :subscription_type => "state_bills"
    s2 = create :subscription, :interest => i1, :subscription_type => "federal_bills"

    delete "/interests/search", {:search_type => "all", :query => i1.in}, login(user)
    assert_response 200

    assert_nil Interest.find(i1.id)
    assert_nil Subscription.find(s1.id)
    assert_nil Subscription.find(s2.id)
  end


  # Eventually: tests on subscriptions with no keyword at all


  # unit testing on subscription deserialization

  def test_subscription_deserialization
    user = create :user
    query = "environment"
    query2 = "foia"
    interest = create :interest, :in => query, :interest_type => "search"
    interest2 = create :interest, :in => query2, :interest_type => "search"
    s1 = create(:subscription, 
        :interest_in => query, :interest => interest, :user => user,
        :subscription_type => "federal_bills", 
        :data => {"query" => query}
    )
    s2 = create(:subscription, 
        :interest_in => query, :interest => interest, :user => user,
        :subscription_type => "state_bills", 
        :data => {"query" => query}
    )
    s3 = create(:subscription, 
        :interest_in => query, :interest => interest, :user => user,
        :subscription_type => "state_bills", 
        :data => {"query" => query, 'state' => "CA"}
    )

    # a subscription which is this users' only one for that subscription_type, but has extra data
    s4 = create(:subscription, 
        :interest_in => query, :interest => interest, :user => user,
        :subscription_type => "speeches", 
        :data => {"query" => query, 'state' => "CA"}
    )

    subscription = Subscription.for user, "federal_bills", query, {'query' => query}
    assert !subscription.new_record?
    assert_equal s1, subscription

    subscription = Subscription.for nil, "federal_bills", query, {'query' => query}
    assert subscription.new_record?

    subscription = Subscription.for user, "federal_bills", query, {'state' => "CA", 'query' => query}
    assert subscription.new_record?
    
    subscription = Subscription.for user, "state_bills", query, {'state' => "CA", 'query' => query}
    assert !subscription.new_record?, "Subscription#for should find subscriptions even when data hash key order differs"
    assert_equal s3, subscription

    subscription = Subscription.for user, "speeches", query, {'state' => "CA", 'query' => query, }
    assert !subscription.new_record?
    assert_equal s4, subscription

    subscription = Subscription.for user, "speeches", query, {'query' => query}
    assert subscription.new_record?, "Subscription#for should not find subscriptions more specific than the type asked for"
  end

end
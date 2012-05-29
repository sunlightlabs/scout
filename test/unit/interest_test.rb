require './test/test_helper'

class InterestTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  


  # TODO: axe this
  
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
require './test/test_helper'

class RoutingTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  class Anonymous; extend Helpers::Routing; end
  def routing; Anonymous; end

  # unit tests on subscriptions

  def test_subscription_path
    user = create :user

    query_and_data = user.subscriptions.create! :subscription_type => "federal_bills", :interest_in => "yes", :data => {'query' => "yes", 'stage' => "enacted"}
    assert_equal "/search/federal_bills/yes?federal_bills[stage]=enacted", routing.subscription_path(query_and_data)

    query = "yes and no"
    query_no_data = user.subscriptions.create! :subscription_type => "federal_bills", :interest_in => query, :data => {'query' => query}
    assert_equal "/search/federal_bills/#{URI.encode query}", routing.subscription_path(query_no_data)

    #TODO: when we support query-less searches
    # data_no_query = user.subscriptions.create! :subscription_type => "state_bills", :data => {:state => "CA"}
    # assert_equal "/search/state_bills?state_bills[state]=CA", routing.subscription_path(data_no_query)

    # no_data_no_query = user.subscriptions.create! :subscription_type => "federal_bills", :data => {}
    # assert_equal "/search/federal_bills", routing.subscription_path(no_data_no_query)
  end

end
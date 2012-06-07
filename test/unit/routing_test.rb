require './test/test_helper'

class RoutingTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  class Anonymous; extend Helpers::Routing; end
  def routing; Anonymous; end

  
  def test_interest_path
    user = create :user

    query = "yes and no" # has spaces

    all = search_interest! user, "all", query
    assert_equal "/search/all/#{URI.encode query}", routing.interest_path(all)

    single_search = search_interest! user, "federal_bills", query
    assert_equal "/search/federal_bills/#{URI.encode query}", routing.interest_path(single_search)

    search_with_data = search_interest! user, "federal_bills", query, {'stage' => "enacted"}
    assert_equal "/search/federal_bills/#{URI.encode query}?federal_bills[stage]=enacted", routing.interest_path(search_with_data)

    advanced_search = search_interest! user, "federal_bills", query, {'query_type' => 'advanced'}
    assert_equal "/search/federal_bills/#{URI.encode query}/advanced", routing.interest_path(advanced_search)
  end

end
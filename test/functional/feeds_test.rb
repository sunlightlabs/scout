require './test/test_helper'

class FeedsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_interest_feed
    user = create :user
    query = "transparency accountability"
    interest = search_interest! user, "all", query, query_type: "advanced"

    get "/interest/#{interest.id}.rss"
    assert_response 200
  end

end
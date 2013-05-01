require './test/test_helper'

class FeedsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_interest_feed
    user = create :user
    query = "transparency accountability"
    interest = search_interest! user, "all", query, "advanced"

    get "/interest/#{interest.id}.rss"
    assert_response 200
  end

  def test_interest_feed_json
    user = create :user
    query = "transparency accountability"
    interest = search_interest! user, "all", query, "advanced"

    key = ApiKey.create!(
      email: user.email,
      status: "A",
      key: "not-a-real-key-but-will-be-fine-for-this"
    )

    count = Event.where(type: "json-used").count

    get "/interest/#{interest.id}.json", {apikey: key.key}
    assert_response 200

    assert_equal(count + 1, Event.where(type: "json-used").count)
    assert_equal key.key, Event.where(type: "json-used").last.api_key
  end

end
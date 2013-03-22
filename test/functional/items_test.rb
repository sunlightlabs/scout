require './test/test_helper'

class ItemsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_show_normally_fetches_nothing
    item_id = "hr4192-112"
    item_type = "bill"

    mock_item item_id, item_type
    assert_equal 0, Cache.count

    get "/item/#{item_type}/#{item_id}"
    assert_response 200

    assert_not_match /Due Process/, last_response.body
  end

  def test_show_when_cached_renders_directly
    item_id = "hr4192-112"
    item_type = "bill"

    cache_item item_id, item_type
    assert_equal 1, Cache.where(subscription_type: "federal_bills").count

    get "/item/#{item_type}/#{item_id}"
    assert_response 200

    assert_match /Due Process/, last_response.body
  end

  def test_show_with_bot_fetches_and_renders_directly
    item_id = "hr4192-112"
    item_type = "bill"

    mock_item item_id, item_type
    assert_equal 0, Cache.count

    get "/item/#{item_type}/#{item_id}", {}, {"HTTP_USER_AGENT" => "Googlebot"}
    assert_response 200

    assert_match /Due Process/, last_response.body
  end

  def test_fetch_item_adapter_contents
    item_id = "hr4192-112"
    item_type = "bill"
    subscription_type = "federal_bills_activity"

    get "/fetch/item/#{item_type}/#{item_id}/#{subscription_type}"
    assert_response 200
  end

  def test_fetch_item_adapter_with_bad_adapter
    item_id = "hr4192-112"
    item_type = "bill"
    subscription_type = "nothing"

    get "/fetch/item/#{item_type}/#{item_id}/#{subscription_type}"
    assert_response 404
  end

  def test_fetch_item_itself
    item_id = "hr4192-112"
    item_type = "bill"

    mock_item item_id, item_type

    get "/fetch/item/#{item_type}/#{item_id}"
    assert_response 200
  end

  def test_fetch_item_with_bad_item_type
    item_id = "hr4192-112"
    item_type = "nothing"

    get "/fetch/item/#{item_type}/#{item_id}"
    assert_response 404
  end


  def test_follow_item_and_then_unfollow
    item_id = "hr4192-112"
    item_type = "bill"

    user = create :user

    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count

    mock_item item_id, item_type

    post "/item/#{item_type}/#{item_id}/follow", {}, login(user)
    assert_response 200

    user.reload
    
    assert_equal 1, user.interests.count
    assert_equal item_types[item_type]['subscriptions'].size, user.subscriptions.count

    interest = user.interests.first
    assert_equal item_types[item_type]['subscriptions'].size, interest.subscriptions.count
    assert_equal item_id, interest.in
    assert_equal item_types[item_type]['subscriptions'].sort, interest.subscriptions.map(&:subscription_type).sort

    # idempotent
    post "/item/#{item_type}/#{item_id}/follow", {}, login(user)
    assert_response 200

    user.reload
    assert_equal 1, user.interests.count


    delete "/item/#{item_type}/#{item_id}/unfollow", {}, login(user)
    assert_response 200

    user.reload
    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count

    # can't find it to delete it again
    delete "/item/#{item_type}/#{item_id}/unfollow", {}, login(user)
    assert_response 404

    user.reload
    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count
  end

end
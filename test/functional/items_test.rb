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
    assert_not_match /rel="canonical"/, last_response.body
  end

  def test_show_when_cached_renders_directly
    with_cache_on do
      item_id = "hr4192-112"
      item_type = "bill"

      cache_item item_id, item_type
      assert_equal 1, Cache.where(subscription_type: "federal_bills").count

      get "/item/#{item_type}/#{item_id}"
      assert_response 200

      assert_match /Due Process/, last_response.body
      assert_match /rel="canonical"/, last_response.body
    end
  end

  def test_show_with_bot_when_not_cached_does_not_render_directly
    item_id = "hr4192-112"
    item_type = "bill"

    mock_item item_id, item_type # not url cached
    # not cached in the item repo

    assert_equal 0, Cache.count

    get "/item/#{item_type}/#{item_id}", {}, {"HTTP_USER_AGENT" => "Googlebot"}
    assert_response 200

    assert_not_match /Due Process/, last_response.body
    assert_not_match /rel="canonical"/, last_response.body
  end

  def test_show_with_item_cache_but_not_url_cache_also_renders_directly
    with_cache_on do
      item_id = "hr4192-112"
      item_type = "bill"

      mock_item item_id, item_type # not url cached
      cache_item_direct item_id, item_type # cached in the item repo

      assert_equal 0, Cache.count
      assert_equal 1, Item.count

      get "/item/#{item_type}/#{item_id}"
      assert_response 200

      assert_match /Due Process/, last_response.body
      assert_match /rel="canonical"/, last_response.body
    end
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


  # redirecting and tracking

  # an item page, from a set of search results
  def test_redirecting_from_email
    assert_equal 0, Event.where(type: "email-click").count

    get "/url", {
      from: "email",
      to: "/my/url",
      d: {
        url_type: "item",

        item_id: "state_bills",
        item_type: "anything",
        because: "search"
      }
    }

    assert_redirect "/my/url"

    event = Event.where(type: "email-click").first
    assert_not_nil event

    assert_equal "email-click", event.type
    assert_equal "item", event.url_type
    assert_equal "/my/url", event.to
    assert_equal "state_bills", event.item_id
    assert_equal "anything", event.item_type
    assert_equal "search", event.because
  end

  # not using this, but want to exercise it anyway
  def test_redirect_just_to_redirect
    assert_equal 0, Event.where(type: "email-click").count

    get "/url", {
      to: "http://openstates.org/my/url",
    }

    assert_redirect "http://openstates.org/my/url"

    assert_equal 0, Event.where(type: "email-click").count
  end

  def test_bad_redirect
    assert_equal 0, Event.where(type: "email-click").count

    get "/url"
    assert_response 500

    assert_equal 0, Event.where(type: "email-click").count
  end

end
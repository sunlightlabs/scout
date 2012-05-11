require './test/test_helper'

class ImportTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods


  def test_preview_feed
    url = "http://example.com/rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"

    Subscriptions::Adapters::ExternalFeed.should_receive(:url_to_response).with(url).and_return(stub)
    Subscriptions::Adapters::ExternalFeed.should_receive(:feed_details).with(anything).and_return({
      'title' => original_title, 'description' => original_description
    })

    get "/import/feed/preview", :url => url

    assert_response 200
    response = json_response
    assert_equal response['title'], original_title
    assert_equal response['description'], original_description
  end

  def test_preview_feed_with_invalid_feed_halts
    url = "http://example.com/not-rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"

    Subscriptions::Adapters::ExternalFeed.should_receive(:url_to_response).with(url).and_return(nil)
    Subscriptions::Adapters::ExternalFeed.should_not_receive(:feed_details)

    get "/import/feed/preview", :url => url

    assert_response 500
  end

  def test_preview_feed_with_invalid_items_halts
    url = "http://example.com/broken-rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"

    Subscriptions::Adapters::ExternalFeed.should_receive(:url_to_response).with(url).and_return(stub)
    Subscriptions::Adapters::ExternalFeed.should_receive(:feed_details).with(anything).and_return({
      'title' => original_title, 'description' => original_description
    })
    Subscription.any_instance.should_receive(:search).and_return(nil)

    get "/import/feed/preview", :url => url

    assert_response 500
  end


  def test_create_feed

    # test original title and original description are preserved
  end

  def test_create_feed_requires_login
  end

  def test_create_feed_with_invalid_feed_creates_nothing
  end

  def test_create_feed_with_invalid_url_creates_nothing
  end

end
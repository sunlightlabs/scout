require './test/test_helper'

class ImportTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods


  def test_preview_feed
    url = "http://example.com/rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"

    Subscriptions::Adapters::ExternalFeed.should_receive(:validate_feed).with(url).and_return({
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

    Subscriptions::Adapters::ExternalFeed.should_receive(:validate_feed).with(url).and_return(nil)

    get "/import/feed/preview", :url => url

    assert_response 500
  end

  def test_preview_feed_with_invalid_items_halts
    url = "http://example.com/broken-rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"

    Subscriptions::Adapters::ExternalFeed.should_receive(:validate_feed).with(url).and_return({
      'title' => original_title, 'description' => original_description
    })
    Subscription.any_instance.should_receive(:search).and_return(nil)

    get "/import/feed/preview", :url => url

    assert_response 500
  end


  def test_create_feed
    user = new_user!

    url = "http://example.com/rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"
    new_title = "My Title"

    subscription_count = Subscription.count
    interest_count = Interest.count

    Email.should_receive(:deliver!).with("Feed", anything, anything, anything)

    Subscriptions::Adapters::ExternalFeed.should_receive(:validate_feed).with(url).and_return({
      'title' => original_title, 'description' => original_description
    })

    post "/import/feed/create", {:url => url, :title => new_title}, login(user)
    assert_response 200

    assert_equal(subscription_count + 1, Subscription.count)
    assert_equal(interest_count + 1, Interest.count)

    interest = Interest.where(:in => url).first
    subscription = interest.subscriptions.where(:interest_in => url, :subscription_type => "external_feed").first

    assert_not_nil interest
    assert_not_nil subscription

    # subscription and interest carry identical data
    [subscription, interest].each do |object|
      assert_equal url, object.data['url']
      assert_equal new_title, object.data['title']
      assert_equal original_title, object.data['original_title']
      assert_equal original_description, object.data['original_description']
    end
  end

  def test_create_feed_requires_url
    user = new_user!

    url = "http://example.com/rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"
    new_title = "My Title"

    subscription_count = Subscription.count
    interest_count = Interest.count

    Subscriptions::Adapters::ExternalFeed.stub(:validate_feed).with(url).and_return({
      'title' => original_title, 'description' => original_description
    })

    post "/import/feed/create", {:title => new_title}, login(user)
    assert_response 500

    assert_equal subscription_count, Subscription.count
    assert_equal interest_count, Interest.count
  end

  def test_create_feed_requires_title
    user = new_user!

    url = "http://example.com/rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"
    new_title = "My Title"

    subscription_count = Subscription.count
    interest_count = Interest.count

    Subscriptions::Adapters::ExternalFeed.stub(:validate_feed).with(url).and_return({
      'title' => original_title, 'description' => original_description
    })

    post "/import/feed/create", {:url => url}, login(user)
    assert_response 500

    assert_equal subscription_count, Subscription.count
    assert_equal interest_count, Interest.count
  end

  def test_create_feed_requires_login
    user = new_user!

    url = "http://example.com/rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"
    new_title = "My Title"

    subscription_count = Subscription.count
    interest_count = Interest.count

    Email.should_not_receive(:deliver!)
    Subscriptions::Adapters::ExternalFeed.should_receive(:validate_feed).with(url).and_return({
      'title' => original_title, 'description' => original_description
    })

    post "/import/feed/create", {:url => url, :title => new_title} # no login
    assert_redirect "/"

    assert_equal subscription_count, Subscription.count
    assert_equal interest_count, Interest.count
  end

  def test_create_feed_with_invalid_feed_creates_nothing
    user = new_user!

    url = "http://example.com/not-rss.xml"
    original_title = "Original Title"
    original_description = "Original Description"
    new_title = "My Title"

    subscription_count = Subscription.count
    interest_count = Interest.count

    Email.should_not_receive(:deliver!)
    Subscriptions::Adapters::ExternalFeed.should_receive(:validate_feed).with(url).and_return(nil)

    post "/import/feed/create", {:url => url, :title => new_title}, login(user)
    assert_response 500

    assert_equal subscription_count, Subscription.count
    assert_equal interest_count, Interest.count
  end

end
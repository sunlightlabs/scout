require './test/test_helper'

class CheckTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_poll_subscription
    query = "environment"
    user = create :user
    interest = search_interest! user, "federal_bills", query
    subscription = interest.subscriptions.first

    mock_search subscription
    items = subscription.search

    assert_equal 2, items.size
    items.each do |item|
      assert_equal query, item.interest_in
      assert_equal subscription, item.subscription # even with no id
      assert_equal subscription.subscription_type, item.subscription_type
      assert_equal interest.interest_type, item.interest_type
      assert_equal "bill", item.item_type
    end
  end

end
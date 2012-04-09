require 'test/test_helper'

class SearchTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods

  def test_invalid_subscription_types_are_not_accepted
    Subscription.should_not_receive(:new)
    get "/search/invalid_type/copyright"
    assert_equal 404, last_response.status
  end

  def test_invalid_subscription_types_with_valid_ones_are_weeded_out
    Subscription.should_receive(:new).once
    get "/search/invalid_type,federal_bills/copyright"
    # don't test the response code, it won't work - the stub means the call to new returns nil
  end
  
end
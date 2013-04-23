require './test/test_helper'

class ItemsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  # fetch an arbitrary URL
  def test_fetch_url
    # url = "http://unitedstates.sunlightfoundation.com/documents/bills/113/hr/hr624-113-eh.htm"
    # mock_response url, "urls/hr624-113-eh.htm"

    # Subscriptions::Manager
  end

end
require './test/test_helper'

class SubscriptionsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  class Anonymous; extend Helpers::Subscriptions; end
  def helper; Anonymous; end

  
  def test_excerpt
    
  end

end
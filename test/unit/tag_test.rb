require './test/test_helper'

class TagTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_new_tags
    interest = create :interest

    assert_equal [], interest.tags
    
    interest.new_tags = "a, b"
    assert_equal ["a", "b"], interest.tags

    interest.new_tags = "a big one   ,   with weird spaces and CAPITAL LETTERS ,"
    assert_equal ["a big one", "with weird spaces and capital letters"], interest.tags

    interest.new_tags = "\"with quotes\", 'and single quotes'"
    assert_equal ["with quotes", "and single quotes"], interest.tags

    interest.new_tags = "now with @#%^&- special characters, and even [] brackets"
    assert_equal ["now with special characters", "and even brackets"], interest.tags
  end

end
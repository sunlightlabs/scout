require './test/test_helper'

class TagsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  
  def test_update_tags
    user = create :user
    interest = create :interest, :user => user

    new_tags = "one, after, another"

    assert_equal [], interest.tags

    put "/interest/#{interest.id}", {:interest => {"tags" => new_tags}}, login(user)
    assert_response 200

    assert_equal ["one", "after", "another"], interest.reload.tags

    put "/interest/#{interest.id}", {:interest => {"tags" => ""}}, login(user)
    assert_response 200

    assert_equal [], interest.reload.tags
  end

  def test_add_public_tags
    tag1 = "one"
    tag2 = "two"
    user = create :user

    assert_equal [], user.public_tags

    post "/account/public_tags", {:tag => tag1}, login(user)
    assert_response 200

    assert_equal [tag1], user.reload.public_tags

    post "/account/public_tags", {:tag => tag1}, login(user)
    assert_response 200

    assert_equal [tag1], user.reload.public_tags

    post "/account/public_tags", {:tag => tag2}, login(user)
    assert_response 200

    assert_equal [tag1, tag2], user.reload.public_tags
  end

  def test_remove_public_tags
    tag1 = "one"
    tag2 = "two"
    user = create :user, :public_tags => [tag1, tag2]

    assert_equal [tag1, tag2], user.public_tags

    delete "/account/public_tags", {:tag => tag1}, login(user)
    assert_response 200

    assert_equal [tag2], user.reload.public_tags

    delete "/account/public_tags", {:tag => tag1}, login(user)
    assert_response 200

    assert_equal [tag2], user.reload.public_tags

    delete "/account/public_tags", {:tag => tag2}, login(user)
    assert_response 200

    assert_equal [], user.reload.public_tags
  end

  # unit tests on interest model related to tags

  def test_new_tags
    interest = create :interest

    assert_equal [], interest.tags
    
    interest.new_tags = "a, b"
    assert_equal ["a", "b"], interest.tags

    interest.new_tags = "a big one   ,   with weird spaces ,"
    assert_equal ["a big one", "with weird spaces"], interest.tags

    interest.new_tags = "\"with quotes\", 'and single quotes'"
    assert_equal ["with quotes", "and single quotes"], interest.tags

    interest.new_tags = "now with @#%^& special characters, and even [] brackets"
    assert_equal ["now with special characters", "and even brackets"], interest.tags
  end

end
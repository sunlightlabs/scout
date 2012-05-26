require './test/test_helper'

class TagsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  
  def test_tags_on_interests
    user = create :user
    interest = create :interest, :user => user

    new_tags = "one, after, another"
    serialized = ["one", "after", "another"]
    next_tags = "another,altogether"

    assert_equal [], interest.tags
    assert_equal 0, user.tags.count


    put "/interest/#{interest.id}", {:interest => {"tags" => new_tags}}, login(user)
    assert_response 200

    assert_equal serialized, interest.reload.tags
    assert_equal serialized.sort, user.reload.tags.map(&:name).sort


    put "/interest/#{interest.id}", {:interest => {"tags" => next_tags}}, login(user)
    assert_response 200

    assert_equal ["another", "altogether"], interest.reload.tags
    assert_equal (serialized + ["altogether"]).sort, user.reload.tags.map(&:name).sort


    put "/interest/#{interest.id}", {:interest => {"tags" => ""}}, login(user)
    assert_response 200

    assert_equal [], interest.reload.tags
    assert_equal (serialized + ["altogether"]).sort, user.reload.tags.map(&:name).sort
  end

  def test_update_tag_public
    user = create :user
    name1 = "one"
    name2 = "two"
    tag1 = create :tag, :name => name1, :user => user
    tag2 = create :tag, :name => name2, :user => user

    assert tag1.private?


    # turn it on
    put "/account/tag/#{name1}", {:tag => {"public" => true}}, login(user)
    assert_response 200

    assert tag1.reload.public?


    # turn it off
    put "/account/tag/#{name1}", {:tag => {'public' => false}}, login(user)
    assert_response 200

    assert tag1.reload.private?


    # turn it off again
    put "/account/tag/#{name1}", {:tag => {'public' => false}}, login(user)
    assert_response 200

    assert tag1.reload.private?    


    # turn on another one
    put "/account/tag/#{name2}", {:tag => {'public' => true}}, login(user)
    assert_response 200

    assert tag1.reload.private?
    assert tag2.reload.public?

    assert_equal 2, user.reload.tags.count
  end

  def test_update_tag_public_doesnt_exist
    name = "one"
    user = create :user

    assert_equal 0, user.tags.where(:tag => name).count

    put "/account/tag/#{name}", {:tag => {'public' => true}}, login(user)
    assert_response 404
  end

  # unit tests on interest model related to tags

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
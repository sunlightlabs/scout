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

  def test_two_users_can_have_same_tag
    user1 = create :user
    user2 = create :user
    interest1 = create :interest, :user => user1
    interest2 = create :interest, :user => user2

    new_tags = "one, two, three"

    assert_equal 0, Tag.count
    assert_equal 0, user1.tags.count
    assert_equal 0, user2.tags.count

    
    put "/interest/#{interest1.id}", {:interest => {"tags" => new_tags}}, login(user1)
    assert_response 200

    assert_equal 3, Tag.count
    assert_equal 3, user1.tags.count
    assert_equal 0, user2.tags.count


    put "/interest/#{interest2.id}", {:interest => {"tags" => new_tags}}, login(user2)
    assert_response 200

    assert_equal 6, Tag.count
    assert_equal 3, user1.tags.count
    assert_equal 3, user2.tags.count
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

  def test_update_tag_description_ones_own
    # todo
  end

  def test_update_tag_description_someone_elses
    # todo
  end

  def test_update_tag_description_not_logged_in
    # todo
  end

  def test_delete_tags_en_masse
    name1 = "one tag"
    name2 = "two"
    name3 = "three"

    user = create :user
    tag1 = create :tag, :user => user, :name => name1
    tag2 = create :tag, :user => user, :name => name2
    tag3 = create :tag, :user => user, :name => name3

    assert_equal 3, Tag.count
    assert_equal 3, user.tags.count

    delete "/account/tags", {:names => [name1]}, login(user)
    assert_redirect "/account/subscriptions"

    assert_equal 2, Tag.count
    assert_equal 2, user.tags.count
    assert_equal 0, user.tags.where(:name => name1).count

    delete "/account/tags", {:names => [name2, name3]}, login(user)
    assert_redirect "/account/subscriptions"

    assert_equal 0, Tag.count
    assert_equal 0, user.tags.count
  end

  def test_delete_tags_not_logged_in
    name1 = "one tag"

    user = create :user
    tag1 = create :tag, :user => user, :name => name1

    assert_equal 1, Tag.count
    assert_equal 1, user.tags.count

    delete "/account/tags", {:names => [name1]}, {}
    assert_redirect '/'

    assert_equal 1, Tag.count
    assert_equal 1, user.tags.count
  end

  def test_delete_others_tags_doesnt_work
    name1 = "one tag"

    user = create :user
    tag = create :tag, :user => user, :name => name1

    other_user = create :user
    other_tag = create :tag, :user => other_user, :name => name1

    assert_equal 2, Tag.count
    assert_equal 1, user.tags.count
    assert_equal 1, other_user.tags.count

    delete "/account/tags", {:names => [name1]}, login(other_user)
    assert_redirect "/account/subscriptions"

    assert_equal 1, Tag.count
    assert_equal 1, user.tags.count
    assert_equal 0, other_user.tags.count
  end

  def test_delete_tags_also_removes_that_tag_from_users_interests
    name1 = "one tag"
    name2 = "two"
    name3 = "three"
    name4 = "four"
    name5 = "five"

    user1 = create :user
    tag1 = create :tag, :user => user1, :name => name1
    tag2 = create :tag, :user => user1, :name => name2
    tag3 = create :tag, :user => user1, :name => name3
    tag4 = create :tag, :user => user1, :name => name4
    tag5 = create :tag, :user => user1, :name => name5

    interest1 = create :interest, :user => user1, :tags => [name1, name2]
    interest2 = create :interest, :user => user1, :tags => [name3]
    interest3 = create :interest, :user => user1, :tags => [name3, name4, name5]

    user2 = create :user
    tag4 = create :tag, :user => user2, :name => name1
    tag5 = create :tag, :user => user2, :name => name3
    tag6 = create :tag, :user => user2, :name => name5
    interest4 = create :interest, :user => user2, :tags => [name1, name3, name5]

    assert_equal 8, Tag.count
    assert_equal 5, user1.tags.count
    assert_equal 3, user2.tags.count

    
    delete "/account/tags", {:names => [name3]}, login(user1)
    assert_redirect "/account/subscriptions"

    assert_equal 7, Tag.count
    assert_equal 4, user1.tags.count
    assert_equal 3, user2.tags.count

    assert_equal [name1, name2], interest1.reload.tags
    assert_equal [], interest2.reload.tags
    assert_equal [name4, name5], interest3.reload.tags
    assert_equal [name1, name3, name5], interest4.reload.tags


    delete "/account/tags", {:names => [name1, name5]}, login(user1)
    assert_redirect "/account/subscriptions"

    assert_equal 5, Tag.count
    assert_equal 2, user1.tags.count
    assert_equal 3, user2.tags.count

    assert_equal [name2], interest1.reload.tags
    assert_equal [], interest2.reload.tags
    assert_equal [name4], interest3.reload.tags
    assert_equal [name1, name3, name5], interest4.reload.tags
  end

  def test_public_tags_ones_own
    username = "valid_name"
    user = create :user, :username => username
    tag = create :tag, :user => user, :public => true

    assert tag.public?

    get "/user/#{user.username}/#{Tag.slugify tag.name}", {}, login(user)
    assert_response 200
  end

  def test_public_tag_someone_elses
    username = "valid_name"
    user = create :user, :username => username
    tag = create :tag, :user => user, :public => true

    user2 = create :user, :username => username.succ

    assert tag.public?

    get "/user/#{user.username}/#{Tag.slugify tag.name}", {}, login(user2)
    assert_response 200
  end

  def test_public_tag_not_logged_in
    username = "valid_name"
    user = create :user, :username => username
    tag = create :tag, :user => user, :public => true

    assert tag.public?

    get "/user/#{user.username}/#{Tag.slugify tag.name}", {}
    assert_response 200
  end

  def test_private_tag_ones_own
    username = "valid_name"
    user = create :user, :username => username
    tag = create :tag, :user => user

    assert tag.private?

    get "/user/#{user.username}/#{Tag.slugify tag.name}", {}, login(user)
    assert_response 200
  end

  def test_private_tag_someone_elses_not_found
    username = "valid_name"
    user = create :user, :username => username
    tag = create :tag, :user => user

    user2 = create :user, :username => username.succ

    assert tag.private?

    get "/user/#{user.username}/#{Tag.slugify tag.name}", {}, login(user2)
    assert_response 404
  end

  def test_private_tag_not_logged_in_not_found
    username = "valid_name"
    user = create :user, :username => username
    tag = create :tag, :user => user

    assert tag.private?

    get "/user/#{user.username}/#{Tag.slugify tag.name}", {}
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
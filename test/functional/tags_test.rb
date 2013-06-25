require './test/test_helper'

class TagsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_follow_tag
    name = "foia"
    name2 = "open government"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name
    tag2 = create :public_tag, user: sharing, name: name2

    user = create :user
    assert_equal 0, user.interests.count

    post "/user/#{sharing.username}/#{name}/follow", {}, login(user)
    assert_response 200

    assert_equal 1, user.interests.count
    interest = user.interests.where(in: tag.id.to_s).first
    assert_not_nil interest
    assert_equal tag, interest.tag
    assert_equal sharing, interest.tag_user

    # idempotent
    post "/user/#{sharing.username}/#{Tag.slugify tag.name}/follow", {}, login(user)
    assert_response 200

    assert_equal 1, user.reload.interests.count

    # lookup by user ID should also work
    post "/user/#{sharing.id.to_s}/#{Tag.slugify tag2.name}/follow", {}, login(user)
    assert_response 200

    assert_equal 2, user.reload.interests.count
    interest = user.interests.where(in: tag2.id.to_s).first
    assert_not_nil interest
    assert_equal tag2, interest.tag
    assert_equal sharing, interest.tag_user
  end

  def test_follow_ones_own_tag_not_allowed
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name

    assert_equal 0, sharing.interests.count

    post "/user/#{sharing.username}/#{tag.name}/follow", {}, login(sharing)
    assert_response 500

    assert_equal 0, sharing.reload.interests.count
  end

  def test_follow_private_tag_not_allowed
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :tag, user: sharing, name: name

    assert tag.private?

    user = create :user
    assert_equal 0, user.interests.count

    post "/user/#{sharing.username}/#{tag.name}/follow", {}, login(user)
    assert_response 404

    assert_equal 0, user.reload.interests.count
    assert_nil user.interests.where(in: tag.id.to_s).first
  end

  def test_follow_nonexistent_tag
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name

    user = create :user
    assert_equal 0, user.interests.count

    post "/user/#{sharing.username}/#{tag.name.succ}/follow", {}, login(user)
    assert_response 404

    assert_equal 0, user.reload.interests.count
  end

  def test_follow_not_logged_in
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name

    user = create :user
    assert_equal 0, user.interests.count

    post "/user/#{sharing.username}/#{tag.name}/follow", {}
    assert_redirect '/'

    assert_equal 0, user.reload.interests.count
  end

  def test_unfollow_tag
    name = "foia"
    name2 = "open government"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name
    tag2 = create :public_tag, user: sharing, name: name2

    user = create :user
    interest1 = Interest.for_tag(user, sharing, tag)
    assert interest1.new_record?
    interest1.save!
    interest2 = Interest.for_tag(user, sharing, tag2)
    assert interest2.new_record?
    interest2.save!

    assert_equal 2, user.interests.count

    delete "/user/#{sharing.username}/#{Tag.slugify tag.name}/unfollow", {} ,login(user)
    assert_response 200

    assert_equal 1, user.reload.interests.count
    assert_nil user.interests.where(in: tag.id.to_s).first
    assert_not_nil user.interests.where(in: tag2.id.to_s).first

    # idempotent
    delete "/user/#{sharing.username}/#{Tag.slugify tag.name}/unfollow", {} ,login(user)
    assert_response 200

    assert_equal 1, user.reload.interests.count
    assert_nil user.interests.where(in: tag.id.to_s).first
    assert_not_nil user.interests.where(in: tag2.id.to_s).first

    # lookup by user ID should also work
    delete "/user/#{sharing.id.to_s}/#{Tag.slugify tag2.name}/unfollow", {} ,login(user)
    assert_response 200

    assert_equal 0, user.reload.interests.count
    assert_nil user.interests.where(in: tag.id.to_s).first
    assert_nil user.interests.where(in: tag2.id.to_s).first
  end

  def unfollow_not_logged_in
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name

    user = create :user
    interest = Interest.for_tag user, sharing, tag
    interest.save!

    assert_equal 1, user.interests.count

    delete "/user/#{sharing.username}/#{Tag.slugify tag.name}/unfollow", {}, login(user)
    assert_redirect '/'

    assert_equal 1, user.reload.interests.count
  end

  def unfollow_nonexistent_tag
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name

    user = create :user
    interest = Interest.for_tag user, sharing, tag
    interest.save!

    assert_equal 1, user.interests.count

    delete "/user/#{sharing.username}/#{Tag.slugify tag.name.succ}/unfollow", {}, login(user)
    assert_response 404

    assert_equal 1, user.reload.interests.count
  end

  def test_tags_on_interests
    user = create :user

    interest = search_interest! user

    new_tags = "one, after, another"
    serialized = ["one", "after", "another"]
    next_tags = "another,altogether"
    new_tags_with_spaces = " one , after  , another "

    assert_equal [], interest.tags
    assert_equal 0, user.tags.count


    put "/interest/#{interest.id}", {interest: {collections: new_tags}}, login(user)
    assert_response 200

    assert_equal serialized, interest.reload.tags
    assert_equal serialized.sort, user.reload.tags.map(&:name).sort

    # spaces affect nothing
    put "/interest/#{interest.id}", {interest: {collections: new_tags_with_spaces}}, login(user)
    assert_response 200

    assert_equal serialized, interest.reload.tags
    assert_equal serialized.sort, user.reload.tags.map(&:name).sort


    put "/interest/#{interest.id}", {interest: {collections: next_tags}}, login(user)
    assert_response 200

    assert_equal ["another", "altogether"], interest.reload.tags
    assert_equal (serialized + ["altogether"]).sort, user.reload.tags.map(&:name).sort


    put "/interest/#{interest.id}", {interest: {collections: ""}}, login(user)
    assert_response 200

    assert_equal [], interest.reload.tags
    assert_equal (serialized + ["altogether"]).sort, user.reload.tags.map(&:name).sort
  end

  def test_tag_interest_cannot_be_tagged
    name = "foia"
    sharing = create :user, username: "johnson"
    tag = create :public_tag, user: sharing, name: name

    user = create :user
    interest = Interest.for_tag user, sharing, tag
    interest.save!

    new_tags = "one, after, another"
    serialized = ["one", "after", "another"]

    assert_equal [], interest.tags

    put "/interest/#{interest.id}", {interest: {collections: new_tags}}, login(user)
    assert_response 500

    assert_equal [], interest.reload.tags
  end

  def test_two_users_can_have_same_tag
    user1 = create :user
    user2 = create :user
    interest1 = search_interest! user1
    interest2 = search_interest! user2

    new_tags = "one, two, three"

    assert_equal 0, Tag.count
    assert_equal 0, user1.tags.count
    assert_equal 0, user2.tags.count


    put "/interest/#{interest1.id}", {interest: {collections: new_tags}}, login(user1)
    assert_response 200

    assert_equal 3, Tag.count
    assert_equal 3, user1.tags.count
    assert_equal 0, user2.tags.count


    put "/interest/#{interest2.id}", {interest: {collections: new_tags}}, login(user2)
    assert_response 200

    assert_equal 6, Tag.count
    assert_equal 3, user1.tags.count
    assert_equal 3, user2.tags.count
  end


  def test_update_tag_public
    user = create :user
    name1 = "one"
    name2 = "two"
    tag1 = create :tag, name: name1, user: user
    tag2 = create :tag, name: name2, user: user

    assert tag1.private?


    # turn it on
    put "/account/collection/#{name1}/public", {public: true}, login(user)
    assert_response 302

    assert tag1.reload.public?


    # turn it off
    put "/account/collection/#{name1}/public", {:public => false}, login(user)
    assert_response 302

    assert tag1.reload.private?


    # turn it off again
    put "/account/collection/#{name1}/public", {:public => false}, login(user)
    assert_response 302

    assert tag1.reload.private?


    # turn on another one
    put "/account/collection/#{name2}/public", {:public => true}, login(user)
    assert_response 302

    assert tag1.reload.private?
    assert tag2.reload.public?

    assert_equal 2, user.reload.tags.count
  end

  def test_update_tag_public_doesnt_exist
    name = "one"
    user = create :user

    assert_equal 0, user.tags.where(:tag => name).count

    put "/account/collection/#{name}/public", {:public => true}, login(user)
    assert_response 404
  end


  def test_update_tag_description_ones_own
    user = create :user
    tag = create :tag, :user => user, :description => nil

    assert_nil tag.description

    description = "new description"
    description2 = "new new description"


    put "/account/collection/#{Tag.slugify tag.name}/description", {:description => description}, login(user)
    assert_response 200

    assert_not_nil json_response['description_pane'][description]
    assert_equal description, tag.reload.description

    put "/account/collection/#{Tag.slugify tag.name}/description", {:description => description2}, login(user)
    assert_response 200

    assert_not_nil json_response['description_pane'][description2]
    assert_equal description2, tag.reload.description
  end

  def test_update_tag_description_someone_elses
    user = create :user
    tag = create :tag, :user => user, :description => nil

    other_user = create :user

    assert_nil tag.description

    description = "new description"

    put "/account/collection/#{Tag.slugify tag.name}/description", {:description => description}, login(other_user)
    assert_response 404

    assert_nil tag.reload.description
  end

  def test_update_tag_description_not_logged_in
    user = create :user
    tag = create :tag, :user => user, :description => nil

    assert_nil tag.description

    description = "new description"
    description2 = "new new description"

    put "/account/collection/#{Tag.slugify tag.name}/description", {:description => description}, {}
    assert_redirect '/'

    assert_nil tag.reload.description
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

    delete "/account/collections", {:names => [name1]}, login(user)
    assert_redirect "/account/subscriptions"

    assert_equal 2, Tag.count
    assert_equal 2, user.tags.count
    assert_equal 0, user.tags.where(:name => name1).count

    delete "/account/collections", {:names => [name2, name3]}, login(user)
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

    delete "/account/collections", {:names => [name1]}, {}
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

    delete "/account/collections", {:names => [name1]}, login(other_user)
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

    interest1 = search_interest! user1, "all", "a", "simple", {}, :tags => [name1, name2]
    interest2 = search_interest! user1, "all", "b", "simple", {}, :tags => [name3]
    interest3 = search_interest! user1, "all", "c", "simple", {}, :tags => [name3, name4, name5]

    user2 = create :user
    tag4 = create :tag, :user => user2, :name => name1
    tag5 = create :tag, :user => user2, :name => name3
    tag6 = create :tag, :user => user2, :name => name5
    interest4 = search_interest! user2, "all", "d", "simple", {}, :tags => [name1, name3, name5]

    assert_equal 8, Tag.count
    assert_equal 5, user1.tags.count
    assert_equal 3, user2.tags.count


    delete "/account/collections", {:names => [name3]}, login(user1)
    assert_redirect "/account/subscriptions"

    assert_equal 7, Tag.count
    assert_equal 4, user1.tags.count
    assert_equal 3, user2.tags.count

    assert_equal [name1, name2], interest1.reload.tags
    assert_equal [], interest2.reload.tags
    assert_equal [name4, name5], interest3.reload.tags
    assert_equal [name1, name3, name5], interest4.reload.tags


    delete "/account/collections", {:names => [name1, name5]}, login(user1)
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

end
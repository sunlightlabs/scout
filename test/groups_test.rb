require './test/test_helper'

class RoutingTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  
  # making groups

  def test_create_group
    user = create :user
    name = "Groupness"

    assert_equal 0, user.groups.count

    post "/groups", {"group" => {"name" => name}}, login(user)
    assert_response 200

    assert_equal 1, user.groups.count
    group = user.groups.first
    assert_equal name, group.name
    assert_equal name.downcase, group.slug

    assert_equal group.id.to_s, json_response['group_id']
    assert_not_nil json_response['groups_pane']
  end

  def test_create_not_logged_in
    user = create :user
    name = "Groupness"

    assert_equal 0, user.groups.count

    post "/groups", {"group" => {"name" => name}}
    assert_redirect "/"

    assert_equal 0, user.groups.count
  end

  def test_create_group_invalid_name
    user = create :user
    name = "Groupness"

    assert_equal 0, user.groups.count

    post "/groups", {"group" => {"name" => ""}}, login(user)
    assert_response 500

    assert_equal 0, user.groups.count

    assert_not_nil json_response['errors']
  end

  def test_create_group_duplicate_name
    user = create :user
    name = "Groupness"

    create :group, :name => name, :user => user

    assert_equal 1, user.groups.count

    post "/groups", {"group" => {"name" => name}}, login(user)
    assert_response 500

    assert_equal 1, user.groups.count
    assert_not_nil json_response['errors']
  end


  # removing a group

  # def test_delete_group
  # end

  # def test_delete_someone_elses_group
  # end

  # def test_delete_nonexistent_group
  # end

  # def test_delete_group_not_logged_in
  # end

  
  # assigning an interest to a group

  def test_assign_interest_to_group
    user = create :user
    interest = create :interest, :user => user
    group = create :group, :user => user

    assert_equal 0, group.interests.count
    assert_equal nil, interest.group

    put "/groups/assign/#{group.slug}", {:interest_ids => [interest.id.to_s]}, login(user)
    assert_response 200

    assert_equal 1, group.reload.interests.count
    assert_equal group, interest.reload.group
  end

  def test_assign_multiple_interests_to_group
    user = create :user
    i1 = create :interest, :user => user
    i2 = create :interest, :user => user
    i3 = create :interest, :user => user
    group = create :group, :user => user

    assert_equal 0, group.interests.count
    [i1, i2, i3].each do |i|
      assert_equal nil, i.group
    end

    put "/groups/assign/#{group.slug}", {:interest_ids => [i1.id.to_s, i2.id.to_s]}, login(user)
    assert_response 200

    assert_equal 2, group.reload.interests.count
    [i1, i2].each do |i|
      assert_equal group, i.reload.group
    end
    assert_equal nil, i3.reload.group
  end

  def test_assign_interest_to_someone_elses_group
    user = create :user
    user2 = create :user
    interest = create :interest, :user => user
    group = create :group, :user => user2

    assert_equal 0, group.interests.count
    assert_equal nil, interest.group

    put "/groups/assign/#{group.slug}", {:interest_ids => [interest.id.to_s]}, login(user)
    assert_response 404

    assert_equal 0, group.reload.interests.count
    assert_equal nil, interest.reload.group    
  end

  def test_assign_interest_not_logged_in
    user = create :user
    interest = create :interest, :user => user
    group = create :group, :user => user

    assert_equal 0, group.interests.count
    assert_equal nil, interest.group

    put "/groups/assign/#{group.slug}", {:interest_ids => [interest.id.to_s]}
    assert_redirect "/"

    assert_equal 0, group.reload.interests.count
    assert_equal nil, interest.reload.group
  end


  # removing an interest from any group

  def test_unassign_interest_from_any_group
    user = create :user
    group = create :group, :user => user
    interest = create :interest, :group => group, :user => user

    assert_equal 1, group.interests.count
    assert_equal group, interest.group

    put "/groups/assign", {:interest_ids => [interest.id.to_s]}, login(user)
    assert_response 200

    assert_equal 0, group.reload.interests.count
    assert_equal nil, interest.reload.group
  end

  def test_unassign_multiple_interests_from_any_group
    user = create :user
    group = create :group, :user => user
    i1 = create :interest, :group => group, :user => user
    i2 = create :interest, :group => group, :user => user
    i3 = create :interest, :group => group, :user => user

    assert_equal 3, group.interests.count
    [i1, i2, i3].each do |i|
      assert_equal group, i.group
    end

    put "/groups/assign", {:interest_ids => [i1.id.to_s, i2.id.to_s]}, login(user)
    assert_response 200

    assert_equal 1, group.reload.interests.count
    [i1, i2].each {|i| assert_equal nil, i.reload.group}
    assert_equal group, i3.reload.group
  end

  def test_unassign_interest_not_logged_in
    user = create :user
    group = create :group, :user => user
    interest = create :interest, :group => group, :user => user

    assert_equal 1, group.interests.count
    assert_equal group, interest.group

    put "/groups/assign", {:interest_ids => [interest.id.to_s]}
    assert_redirect "/"

    assert_equal 1, group.reload.interests.count
    assert_equal group, interest.reload.group
  end


  # group RSS and JSON feeds

  def test_group_rss_feed
  end

  def test_group_json_feed
  end

end
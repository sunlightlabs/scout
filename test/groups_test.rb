require './test/test_helper'

class RoutingTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

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

end
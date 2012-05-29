require './test/test_helper'

class ItemsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_fetch_item_adapter_contents
    item_id = "hr4192-112"
    item_type = "bill"
    subscription_type = "federal_bills_activity"

    get "/fetch/item/#{item_type}/#{item_id}/#{subscription_type}"
    assert_response 200
  end

  def test_fetch_item_adapter_with_bad_adapter
    item_id = "hr4192-112"
    item_type = "bill"
    subscription_type = "nothing"

    get "/fetch/item/#{item_type}/#{item_id}/#{subscription_type}"
    assert_response 404
  end

  # TODO: need fixtures, the render step breaks without having actual data
  # def test_fetch_item_itself
  #   item_id = "hr4192-112"
  #   item_type = "bill"

  #   get "/fetch/item/#{item_type}/#{item_id}"
  #   assert_response 200
  # end

  def test_fetch_item_with_bad_item_type
    item_id = "hr4192-112"
    item_type = "nothing"

    get "/fetch/item/#{item_type}/#{item_id}"
    assert_response 404
  end


  def test_follow_item_and_then_unfollow
    item_id = "hr4192-112"
    item_type = "bill"

    user = create :user

    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count

    item = SeenItem.new(:item_id => item_id, :date => Time.now, :data => {
     :bill_id => item_id,
     :enacted => true
    })
    Subscriptions::Manager.stub(:find).and_return(item)

    post "/item/#{item_type}/#{item_id}/follow", {}, login(user)
    assert_response 200

    user.reload
    assert_equal 1, user.interests.count
    interest = user.interests.first
    assert_equal item_types[item_type]['subscriptions'].size, interest.subscriptions.count
    assert_equal item_id, interest.in
    assert_equal item_types[item_type]['subscriptions'].sort, interest.subscriptions.map(&:subscription_type).sort

    # idempotent
    post "/item/#{item_type}/#{item_id}/follow", {}, login(user)
    assert_response 200

    user.reload
    assert_equal 1, user.interests.count


    delete "/item/#{item_type}/#{item_id}/unfollow", {}, login(user)
    assert_response 200

    user.reload
    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count

    # can't find it to delete it again
    delete "/item/#{item_type}/#{item_id}/unfollow", {}, login(user)
    assert_response 404

    user.reload
    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count
  end

end
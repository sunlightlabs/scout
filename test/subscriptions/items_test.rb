require './test/test_helper'

class ItemsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_fetch_item_adapter_contents
    item_id = "hr4192-112"
    item_type = "bill"

    user = create :user
    interest = create :bill_interest, :user => user, :in => item_id, :item_type => item_type

    

    Subscriptions::Manager.search
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

    delete "/item/#{item_type}/#{item_id}/unfollow", {}, login(user)
    assert_response 200

    user.reload
    assert_equal 0, user.interests.count
    assert_equal 0, user.subscriptions.count
  end

end
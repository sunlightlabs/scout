require './test/test_helper'

class RemoteTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_subscribe_by_sms
    phone = "+16173140966"
    item_id = "hr4192-112"
    item_type = "bill"

    mock_item item_id, item_type

    assert_nil User.where(:phone => phone).first
    interest_count = Interest.count
    subscriptions_count = Subscription.count

    # verify SMS was sent to the user telling them to confirm
    SMS.should_receive(:deliver!).with("Remote Subscription", phone, anything)

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "item", :item_id => item_id, :item_type => item_type,
      :source => "testing"
    }
    assert_response 200

    user = User.where(:phone => phone).first
    assert_not_nil user

    assert !user.confirmed?
    assert_equal "none", user.notifications

    assert_not_nil user.password_hash
    assert user.should_change_password
    assert_equal "testing", user.source

    assert_equal phone, user.phone
    assert !user.phone_confirmed?

    assert !user.announcements
    assert !user.sunlight_announcements

    assert_equal 1, user.interests.count
    interest = user.interests.first

    assert_equal "item", interest.interest_type
    assert_equal item_type, interest.item_type
    assert_equal item_id, interest.in
    assert_not_nil interest.data['bill_id'] # loaded from fixture
  end

  def test_subscribe_by_sms_with_taken_phone_number_creates_new_interest_but_not_new_account
    phone = "+16173140966"
    item_id = "hr4192-112"
    item_type = "bill"

    user = create :user, :phone => phone # confirmation doesn't matter
    assert user.confirmed?

    mock_item item_id, item_type

    count = User.count
    assert_equal 0, user.interests.count

    # SMS should not be sent
    SMS.should_not_receive(:deliver!).with("Remote Subscription", phone, anything)

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "item", :item_id => item_id, :item_type => item_type,
      :source => "testing"
    }
    assert_response 200

    user.reload
    assert_equal count, User.count
    assert_equal 1, user.interests.count
    assert user.confirmed? # still got it

    interest = user.interests.first

    assert_equal "item", interest.interest_type
    assert_equal item_type, interest.item_type
    assert_equal item_id, interest.in
    assert_not_nil interest.data['bill_id'] # loaded from fixture

    # verify *no* SMS was sent to user, not needed
    #TODO
  end

  def test_subscribe_by_sms_with_blank_phone_number_fails
    phone = ""
    item_id = "hr4192-112"
    item_type = "bill"

    mock_item item_id, item_type

    assert_nil User.where(:phone => phone).first
    interest_count = Interest.count
    subscriptions_count = Subscription.count

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "item", :item_id => item_id, :item_type => item_type,
      :source => "testing"
    }
    assert_response 500
    assert_nil User.where(:phone => phone).first
  end

  def test_subscribe_by_sms_with_invalid_interest_details_fails
    # test on 'interest_type', 'item_type', 'item_id'
    phone = "+16173140966"
    item_id = "hr4192-112"
    item_type = "bill"

    assert_nil User.where(:phone => phone).first
    interest_count = Interest.count
    subscriptions_count = Subscription.count

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "item", :item_id => "", :item_type => item_type,
      :source => "testing"
    }
    assert_response 500
    assert_nil User.where(:phone => phone).first

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "", :item_id => item_id, :item_type => item_type,
      :source => "testing"
    }
    assert_response 500
    assert_nil User.where(:phone => phone).first

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "item", :item_id => item_id, :item_type => "",
      :source => "testing"
    }
    assert_response 500
    assert_nil User.where(:phone => phone).first
  end

  def test_subscribe_by_sms_when_remote_item_doesnt_exist_fails
    phone = "+16173140966"
    item_id = "hr4195-112" # no fixture for this
    item_type = "bill"

    mock_item item_id, item_type # should mock it to return nil

    assert_nil User.where(:phone => phone).first
    interest_count = Interest.count
    subscriptions_count = Subscription.count

    post "/remote/subscribe/sms", {
      :phone => phone, :interest_type => "item", :item_id => item_id, :item_type => item_type,
      :source => "testing"
    }
    assert_response 500
  end

  def test_subscribe_by_sms_with_invalid_credentials_fails
  end



end
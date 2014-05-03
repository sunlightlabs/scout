require './test/test_helper'

class RemoteTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_service_sync_new_interests
    service = "service1"
    key = Environment.services["service1"]['secret_key']
    email = "test@example.com"
    notifications = "email_daily"

    # user not created yet
    assert_nil User.where(email: email).first
    count = User.count
    interest_count = Interest.count

    # new item subscription
    item_id = "hr4192-112"
    item_type = "bill"
    mock_item item_id, item_type

    interest1 = {
      'active' => true,
      'changed_at' => Time.now,

      'interest_type' => "item",
      'item_type' => item_type,
      'item_id' => item_id
    }

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest1]
    }.to_json
    assert_response 201

    assert_equal 1, json_response['actions']['added']
    assert_equal 0, json_response['actions']['removed']

    user = User.where(email: email).first
    assert_not_nil user
    assert_equal count + 1, User.count
    assert_equal interest_count + 1, Interest.count

    assert_equal notifications, user.notifications
    assert user.confirmed?
    assert_not_nil user.password_hash
    assert !user.should_change_password?
    assert !user.announcements?
    assert !user.organization_announcements?

    assert_not_nil user.synced_at

    assert_equal 1, user.interests.count
    assert_equal item_id, user.interests.first.in

    # new item subscription for existing user
    item_id = "hr4193-112"
    item_type = "bill"
    mock_item item_id, item_type

    # add this item on, keep old item, should be idempotent
    interest2 = {
      'active' => true,
      'changed_at' => Time.now.to_i, # test out using a posix time

      'interest_type' => "item",
      'item_type' => item_type,
      'item_id' => item_id
    }


    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest1, interest2]
    }.to_json
    assert_response 201

    assert_equal 1, json_response['actions']['added']
    assert_equal 0, json_response['actions']['removed']

    user.reload

    assert_equal count + 1, User.count
    assert_equal interest_count + 2, Interest.count

    assert_equal 2, user.interests.count
    assert_equal item_id, user.interests.last.in

    # pretend an hour has passed
    user.interests.each do |interest|
      interest.update_attribute :updated_at, 1.hour.ago
    end

    # now tear it down
    interest2['active'] = false

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest2]
    }.to_json
    assert_response 201

    assert_equal 0, json_response['actions']['added']
    assert_equal 1, json_response['actions']['removed']

    user.reload

    assert_equal count + 1, User.count
    assert_equal interest_count + 1, Interest.count

    assert_equal 1, user.interests.count
    assert_equal interest1['item_id'], user.interests.last.in


    # tear the first down, add the second one back
    interest1['active'] = false
    interest2['active'] = true
    mock_item interest2['item_id'], interest2['item_type']

    # add in a search interest
    interest3 = {
      'active' => true,
      'changed_at' => Time.now,

      'interest_type' => 'search',
      'search_type' => 'state_bills',
      'in' => 'health',
      'query_type' => 'advanced',
      'filters' => {'state' => 'DE'}
    }


    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest1, interest2, interest3]
    }.to_json
    assert_response 201

    assert_equal 2, json_response['actions']['added']
    assert_equal 1, json_response['actions']['removed']

    user.reload

    assert_equal count + 1, User.count
    assert_equal interest_count + 2, Interest.count

    assert_equal 2, user.interests.count
    assert_equal interest2['item_id'], user.interests.first.in

    search_interest = user.interests.last
    assert_equal interest3['in'], search_interest.in
    assert_equal 'DE', search_interest.data['state']


    # now verify that a user's notifications setting can be updated
    # without having to add/remove stuff
    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: "none",
      interests: [interest1, interest2, interest3]
    }.to_json
    assert_response 201

    assert_equal 0, json_response['actions']['added']
    assert_equal 0, json_response['actions']['removed']

    user.reload

    assert_equal "none", user.notifications
    assert_not_equal notifications, user.notifications

    # now, verify that a user marked as bounced will NOT
    # allow their state to be updated

    user.update_attribute :bounced, true

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest1, interest2, interest3]
    }.to_json
    assert_response 403

    user.reload

    assert_equal "none", user.notifications
    assert_not_equal notifications, user.notifications
  end

  # covers a real bug where Swot was mutating emails in-place,
  # and de-duping was not happening correctly
  def test_service_does_not_lowercase
    service = "service1"
    key = Environment.services["service1"]['secret_key']
    notifications = "email_daily"

    email = "Test@example.com" # capitalized!

    # user doesn't exists
    assert_nil User.where(email: email).first
    count = User.count
    interest_count = Interest.count

    # new item subscription
    item_id = "hr4192-112"
    item_type = "bill"
    mock_item item_id, item_type

    interest1 = {
      'active' => true,
      'changed_at' => Time.now,

      'interest_type' => "item",
      'item_type' => item_type,
      'item_id' => item_id
    }

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest1]
    }.to_json
    assert_response 201

    assert_equal 1, json_response['actions']['added']
    assert_equal 0, json_response['actions']['removed']

    # user created under given email
    assert_not_nil User.where(email: email).first
    assert_nil User.where(email: email.downcase).first

    assert_equal count + 1, User.count
    assert_equal interest_count + 1, Interest.count
  end



  # no key, bunk key, valid key for wrong service
  def test_service_sync_invalid_secret_key
    service = "service1"
    key = Environment.services["service2"]['secret_key']
    email = "test@example.com"

    user = create :service_user, email: email

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key
    }.to_json

    assert_response 403
    assert_match /not a supported service/i, last_response.body
  end

  def test_service_sync_invalid_json
    service = Environment.services.keys.first
    email = "test@example.com"
    user = create :service_user, email: email

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: Environment.services[service]['secret_key']
    }
    assert_response 500
    assert_match /parsing json/i, last_response.body
  end

  # user account exists, but has different service
  def test_service_sync_service_for_native_user
    # a native Scout user
    email = "test@example.com"
    user = create :user, email: email

    # one existing item subscription, native to Scout
    item_id = "hr4192-112"
    item_type = "bill"
    mock_item item_id, item_type

    interest1 = Interest.for_item user, item_id, item_type
    interest1.save!

    count = User.count
    assert_equal 1, user.interests.count


    # now this user joins a remote service, and makes an interest there

    service = Environment.services.keys.first
    notifications = "email_daily"

    item_id = "hr4193-112"
    item_type = "bill"
    mock_item item_id, item_type

    interest2 = {
      'active' => true,
      'changed_at' => Time.now,

      'interest_type' => "item",
      'item_type' => item_type,
      'item_id' => item_id
    }

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: Environment.services[service]['secret_key'],
      notifications: notifications,
      interests: [interest2]
    }.to_json

    assert_response 201

    assert_equal 1, json_response['actions']['added']
    assert_equal 0, json_response['actions']['removed']

    user = User.where(email: email).first

    assert_not_nil user
    assert_equal count, User.count
    assert_equal 2, user.interests.count

    created = user.interests.asc(:_id).last
    assert_equal created.in, item_id
    assert_equal created.item_type, item_type

    # now turn the user's email notifications off

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: Environment.services[service]['secret_key'],
      notifications: "none",
      interests: []
    }.to_json

    assert_response 201

    assert_equal 0, json_response['actions']['added']
    assert_equal 0, json_response['actions']['removed']

    user = User.where(email: email).first
    assert_equal 2, user.interests.count
    assert_equal "none", user.notifications


    # pretend an hour has passed

    user.interests.each do |interest|
      interest.update_attribute :updated_at, 1.hour.ago
    end


    # now remove the first interest

    remove_interest2 = {
      'active' => false,
      'changed_at' => Time.now,

      'interest_type' => "item",
      'item_type' => item_type,
      'item_id' => item_id
    }

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: Environment.services[service]['secret_key'],
      notifications: notifications,
      interests: [remove_interest2]
    }.to_json

    assert_response 201

    assert_equal 0, json_response['actions']['added']
    assert_equal 1, json_response['actions']['removed']

    user = User.where(email: email).first
    assert_equal 1, user.interests.count
    assert_equal interest1.in, user.interests.first.in
    assert_equal notifications, user.notifications # changed back


    # now, remove the *original* native interest, through the sync endpoint
    # this is going to be possible for now.

    remove_interest1 = {
      'active' => false,
      'changed_at' => Time.now,

      'interest_type' => "item",
      'item_type' => interest1.item_type,
      'item_id' => interest1.in
    }

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: Environment.services[service]['secret_key'],
      notifications: notifications,
      interests: [remove_interest1]
    }.to_json

    assert_response 201

    assert_equal 0, json_response['actions']['added']
    assert_equal 1, json_response['actions']['removed']

    user = User.where(email: email).first
    assert_equal 0, user.interests.count
  end

  # bad email, let's say
  def test_service_sync_invalid_user
    service = "service1"
    key = Environment.services["service1"]['secret_key']
    email = "invalid.email"
    notifications = "email_daily"

    # user not created yet
    assert_nil User.where(email: email).first
    count = User.count

    # new item subscription
    item_id = "hr4192-112"
    item_type = "bill"
    mock_item item_id, item_type

    interest1 = {
      'active' => true,
      'changed_at' => Time.now,

      'interest_type' => "item",
      'item_type' => item_type,
      'item_id' => item_id
    }

    post "/remote/service/sync", {
      email: email,
      service: service,
      secret_key: key,
      notifications: notifications,
      interests: [interest1]
    }.to_json

    assert_response 403
    assert_match /invalid new user/i, last_response.body

    assert_equal count, User.count
    assert_nil User.where(email: email).first
  end

end
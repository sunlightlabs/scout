require './test/test_helper'

class AccountsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  ### Update account settings

  def test_update_account_settings
    user = create :user, announcements: true

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements

    put '/account/settings', {user: {notifications: "email_daily", announcements: "false"}}, login(user)
    assert_redirect "/account/settings"

    user.reload

    assert_equal 'email_daily', user.notifications
    assert_equal false, user.announcements
  end

  def test_update_account_settings_invalid
    user = create :user, announcements: true

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements

    put '/account/settings', {user: {notifications: "not_valid", announcements: "false"}}, login(user)
    assert_response 200

    user.reload

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements
  end

  # ensures callbacks on generating a new password don't occur on any old update of the model
  def test_update_account_settings_does_not_reset_password
    user = create :user
    password_hash = user.password_hash

    put '/account/settings', {user: {notifications: "email_immediate", announcements: "false"}}, login(user)
    assert_redirect "/account/settings"

    user.reload

    assert_equal 'email_immediate', user.notifications
    assert_equal false, user.announcements

    assert_equal password_hash, user.password_hash
  end

  def test_update_name_details
    user = create :user
    assert user.display_name.blank?
    assert user.username.blank?

    username = "valid_username"
    display_name = "User Name"

    put '/account/settings', {'user' => {'username' => username, 'display_name' => display_name}}, login(user)
    assert_redirect '/account/settings'

    user.reload
    assert_equal username, user.username
    assert_equal display_name, user.display_name
  end

  def test_update_name_details_invalid
    username = "valid_username"
    display_name = "User Name"

    other_user = create :user, :username => username

    user = create :user
    assert user.display_name.blank?
    assert user.username.blank?

    put '/account/settings', {'user' => {'username' => username, 'display_name' => display_name}}, login(user)
    assert_response 200

    user.reload
    assert user.display_name.blank?
    assert user.username.blank?
  end

  def test_update_name_reserved_name
    user = create :user
    assert user.display_name.blank?
    assert user.username.blank?

    username = reserved_names.first
    display_name = "User Name"

    put '/account/settings', {'user' => {'username' => username, 'display_name' => display_name}}, login(user)
    assert_response 200

    user.reload
    assert user.display_name.blank?
    assert user.username.blank?
  end

  def test_update_name_details_and_valid_password
    password = "test"
    new_password = password.succ

    user = create :user, :password => password, :should_change_password => true

    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)

    assert user.display_name.blank?
    assert user.username.blank?

    old_password_hash = user.password_hash
    username = "valid_username"
    display_name = "User Name"

    put '/account/settings', {
      'user' => {'username' => username, 'display_name' => display_name},
      'old_password' => password, 'password' => new_password, 'password_confirmation' => new_password
      }, login(user)
    assert_redirect '/account/settings'

    user.reload
    assert_equal username, user.username
    assert_equal display_name, user.display_name

    assert_not_equal old_password_hash, user.password_hash
    assert !User.authenticate(user, password)
    assert User.authenticate(user, new_password)
    assert !user.should_change_password
  end

  def test_update_name_details_and_invalid_old_password
    password = "test"
    new_password = password.succ

    user = create :user, :password => password, :should_change_password => true

    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)

    assert user.display_name.blank?
    assert user.username.blank?
    assert user.should_change_password

    old_password_hash = user.password_hash
    username = "valid_username"
    display_name = "User Name"

    put '/account/settings', {
      'user' => {'username' => username, 'display_name' => display_name},
      'old_password' => new_password.succ, 'password' => new_password, 'password_confirmation' => new_password
      }, login(user)
    assert_response 200

    user.reload
    assert user.display_name.blank?
    assert user.username.blank?

    assert_equal old_password_hash, user.password_hash
    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)
    assert user.should_change_password
  end

  def test_update_name_slugifies_username
    user = create :user
    assert user.display_name.blank?
    assert user.username.blank?

    username = "User Name And 2 Things!"
    display_name = "User Name"

    put '/account/settings', {'user' => {'username' => username, 'display_name' => display_name}}, login(user)
    assert_redirect '/account/settings'

    user.reload
    assert_equal "user_name_and_2_things", user.username
    assert_equal display_name, user.display_name
  end




  #### Change password

  def test_change_password
    user = create :user, :password => "test", :password_confirmation => "test", :should_change_password => true

    old_password_hash = user.password_hash
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")
    assert user.should_change_password

    put '/account/settings', {:old_password => "test", :password => "not-test", :password_confirmation => "not-test"}, login(user)
    assert_redirect '/account/settings'

    user.reload
    assert_not_equal old_password_hash, user.password_hash
    assert !User.authenticate(user, "test")
    assert User.authenticate(user, "not-test")
    assert !user.should_change_password
  end

  def test_change_password_not_logged_in
    put '/account/settings', {:old_password => "test", :password => "not-test", :password_confirmation => "not-test"}
    assert_redirect '/'
  end

  def test_change_password_wrong_original_password
    password = "test"
    new_password = password.succ
    user = create :user, :password => password

    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)

    put '/account/settings', {:old_password => new_password.succ, :password => new_password, :password_confirmation => new_password}, login(user)
    assert_response 200

    user.reload
    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)
  end

  def test_change_password_mismatched_new_passwords
    password = "test"
    new_password = password.succ
    user = create :user, password: password

    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)

    put '/account/settings', {old_password: password, password: new_password, password_confirmation: new_password.succ}, login(user)
    assert_response 200

    user.reload
    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)
  end






  #### Unsubscribe ####

  def test_unsubscribe_actual
    user = create :user, organization_announcements: true, announcements: true

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements
    assert_equal true, user.organization_announcements

    post '/account/unsubscribe/actually', {}, login(user)
    assert_redirect "/account/unsubscribe"

    user.reload

    assert_equal 'none', user.notifications
    assert_equal false, user.announcements
    assert_equal false, user.organization_announcements
  end

  def test_unsubscribe_actual_not_logged_in
    post '/account/unsubscribe/actually', {}
    assert_redirect "/"
  end

  # doesn't actually do the unsubscribe
  def test_unsubscribe_landing
    user = create :user, organization_announcements: true, announcements: true

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements
    assert_equal true, user.organization_announcements

    get '/account/unsubscribe', {}, login(user)
    assert_response 200

    user.reload

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements
    assert_equal true, user.organization_announcements
  end

  def test_unsubscribe_landing_not_logged_in
    get '/account/unsubscribe', {}
    assert_redirect "/login?redirect=/account/unsubscribe"
  end

end
require './test/test_helper'

class AccountsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_login
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    assert !user.should_change_password

    post '/login', :email => email, :password => password
    assert_redirect "/"

    user.reload
    assert !user.should_change_password
  end

  def test_login_redirects_back
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    redirect = "/search/federal_bills/anything"

    post '/login', :email => email, :password => password, :redirect => redirect
    assert_redirect redirect
  end
  
  def test_login_invalid
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    assert !user.should_change_password

    post '/login', :email => email, :password => password.succ
    user.reload

    assert !user.should_change_password

    assert_equal 200, last_response.status
    assert_match /Invalid password/, last_response.body
  end

  def test_login_does_not_reset_should_change_password
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password, :should_change_password => true

    assert user.should_change_password

    post '/login', :email => email, :password => password
    user.reload

    assert user.should_change_password

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_logout_redirects_back
    get '/logout'
    assert_redirect '/'
    
    redirect = "/search/federal_bills/anything"
    get '/logout', :redirect => redirect
    assert_redirect redirect
  end

  def test_create_user
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {:email => email, :password => "test", :password_confirmation => "test", :announcements => false, :sunlight_announcements => true}}
    assert_redirect '/account/settings'

    user = User.where(:email => email).first
    assert_not_nil user
    assert User.authenticate(user, "test")
    assert !user.announcements
    assert user.sunlight_announcements
  end

  def test_create_user_redirects_back
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    redirect = "/search/federal_bills/anything"

    post '/account/new', {:user => {:email => email, :password => "test", :password_confirmation => "test"}, :redirect => redirect}
    assert_redirect redirect
  end

  def test_create_user_invalid
    email = "invalid email"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {:email => email, :password => "test", :password_confirmation => "test"}}
    assert_response 200 # render with errors

    assert_nil User.where(:email => email).first
  end

  # normal create user path requires an email
  def test_create_user_without_email_fails
    count = User.count

    post '/account/new', {:user => {:email => "", :password => "test", :password_confirmation => "test"}}
    puts redirect_path
    assert_response 200

    assert_equal count, User.count
  end

  # this has to be done in the controller
  def test_create_user_disallow_blank_passwords
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {:email => email, :password => "", :password_confirmation => ""}}
    assert_response 302
    assert_equal '/login', redirect_path

    assert_nil User.where(:email => email).first
  end

  def test_update_account_settings
    user = create :user

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements

    put '/account/settings', {:user => {:notifications => "email_daily", :announcements => "false"}}, login(user)
    assert_redirect "/account/settings"

    user.reload

    assert_equal 'email_daily', user.notifications
    assert_equal false, user.announcements
  end

  def test_update_account_settings_invalid
    user = create :user

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements

    put '/account/settings', {:user => {:notifications => "not_valid", :announcements => "false"}}, login(user)
    assert_response 200

    user.reload

    assert_equal 'email_immediate', user.notifications
    assert_equal true, user.announcements
  end

  # ensures callbacks on generating a new password don't occur on any old update of the model
  def test_update_account_settings_does_not_reset_password
    user = create :user
    password_hash = user.password_hash

    put '/account/settings', {:user => {:notifications => "email_immediate", :announcements => "false"}}, login(user)
    assert_redirect "/account/settings"

    user.reload

    assert_equal 'email_immediate', user.notifications
    assert_equal false, user.announcements

    assert_equal password_hash, user.password_hash
  end


  # password management

  def test_start_reset_password_process
    # post '/subscriptions', :interest => "testing", :subscription_type => "federal_bills"
    # assert_equal 302, last_response.status
    user = create :user
    old_token = user.reset_token

    Email.should_receive(:deliver!).with("Password Reset Request", user.email, anything, anything)

    post '/account/password/forgot', :email => user.email
    assert_redirect '/login'

    user.reload
    assert_not_equal old_token, user.reset_token
  end

  def test_start_reset_password_process_with_bad_email
    Email.should_not_receive(:deliver!)
    post '/account/password/forgot', :email => "notvalid@example.com"
    assert_redirect '/login'
  end

  def test_visit_reset_password_link
    user = create :user
    reset_token = user.reset_token
    old_password_hash = user.password_hash
    assert !user.should_change_password

    Email.should_receive(:deliver!).with("Password Reset", user.email, anything, anything)

    get '/account/password/reset', :reset_token => reset_token
    assert_redirect '/login'

    user.reload

    assert_not_equal reset_token, user.reset_token
    assert_not_equal old_password_hash, user.password_hash
    assert user.should_change_password
  end

  def test_visit_reset_password_link_with_no_token
    Email.should_not_receive(:deliver!)

    get '/account/password/reset'
    assert_response 404
  end

  def test_visit_reset_password_link_with_invalid_token
    Email.should_not_receive(:deliver!)

    get '/account/password/reset', :reset_token => "whatever"
    assert_response 404
  end

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
    user = create :user, :password => password

    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)

    put '/account/settings', {:old_password => password, :password => new_password, :password_confirmation => new_password.succ}, login(user)
    assert_response 200

    user.reload
    assert User.authenticate(user, password)
    assert !User.authenticate(user, new_password)
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


  # phone settings

  def test_add_phone_number_when_user_has_none
    user = create :user
    phone = "1234567890"

    assert_nil user.phone
    assert !user.phone_confirmed?
    assert_nil user.phone_verify_code
    SMS.should_receive(:deliver).with("Verification Code", phone, anything)

    put '/account/phone', {:user => {:phone => phone}}, login(user)

    user.reload
    assert_equal phone, user.phone
    assert !user.phone_confirmed?
    assert_not_nil user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_add_phone_number_unconfirms_existing_number
    phone1 = "1234567890"
    phone2 = phone1.succ
    original_verify_code = "1234"
    user = create :user, :phone => phone1, :phone_confirmed => true, :phone_verify_code => original_verify_code

    assert user.phone_confirmed?
    SMS.should_receive(:deliver).with("Verification Code", phone2, anything)

    put '/account/phone', {:user => {:phone => phone2}}, login(user)

    user.reload
    assert_equal phone2, user.phone
    assert !user.phone_confirmed?
    assert_not_equal original_verify_code, user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_add_invalid_phone_number
    user = create :user
    invalid_phone = "abcdefghij"

    assert_nil user.phone
    assert !user.phone_confirmed?
    assert_nil user.phone_verify_code

    put '/account/phone', {:user => {:phone => invalid_phone}}, login(user)

    user.reload
    assert_nil user.phone
    assert !user.phone_confirmed?
    assert_nil user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_resend_phone_verification_code
    phone = "1234567890"
    verify_code = "1234"
    user = create :user, :phone => phone, :phone_verify_code => verify_code

    assert !user.phone_confirmed?
    SMS.should_receive(:deliver).with("Resend Verification Code", phone, anything)

    post '/account/phone/resend', {}, login(user)

    user.reload
    assert !user.phone_confirmed?
    # 1 in 10,000 chance this fails even when the code works!
    assert_not_equal verify_code, user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_confirm_phone_verification_code_valid
    phone = "1234567890"
    verify_code = "1234"
    user = create :user, :phone => phone, :phone_verify_code => verify_code

    assert !user.phone_confirmed?

    post '/account/phone/confirm', {:phone_verify_code => verify_code}, login(user)

    user.reload
    assert_equal phone, user.phone
    assert user.phone_confirmed?
    assert_nil user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_confirm_phone_verification_code_invalid
    phone = "1234567890"
    verify_code = "1234"
    user = create :user, :phone => phone, :phone_verify_code => verify_code

    assert !user.phone_confirmed?

    post '/account/phone/confirm', {:phone_verify_code => verify_code.succ}, login(user)

    user.reload
    assert !user.phone_confirmed?
    assert_equal verify_code, user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

end
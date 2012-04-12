require 'test/test_helper'

class AccountsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods

  def test_login
    email = "test@example.com"
    password = "test"
    user = new_user! :email => email, :password => password, :password_confirmation => password

    assert !user.should_change_password

    post '/login', :email => email, :password => password
    user.reload

    assert !user.should_change_password

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
    
  end

  def test_login_invalid
    email = "test@example.com"
    password = "test"
    user = new_user! :email => email, :password => password, :password_confirmation => password

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
    user = new_user! :email => email, :password => password, :password_confirmation => password, :should_change_password => true

    assert user.should_change_password

    post '/login', :email => email, :password => password
    user.reload

    assert user.should_change_password

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_create_user
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {:email => email, :password => "test", :password_confirmation => "test"}}

    user = User.where(:email => email).first
    assert_not_nil user

    assert User.authenticate(user, "test")
    user.delete

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_create_user_invalid
    email = "invalid email"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {:email => email, :password => "test", :password_confirmation => "test"}}

    assert_nil User.where(:email => email).first

    # should render errors
    assert_equal 200, last_response.status
  end

  # this has to be done in the controller
  def test_create_user_disallow_blank_passwords
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {:email => email, :password => "", :password_confirmation => ""}}

    assert_nil User.where(:email => email).first

    assert_equal 302, last_response.status
    assert_equal '/login', redirect_path
  end

  def test_update_account_settings
    user = new_user!

    assert_equal 'email_daily', user.notifications
    assert_equal true, user.announcements

    put '/account/settings', {:user => {:notifications => "email_immediate", :announcements => "false"}}, login(user)

    user.reload

    assert_equal 'email_immediate', user.notifications
    assert_equal false, user.announcements

    assert_equal 200, last_response.status
  end

  def test_update_account_settings_invalid
    user = new_user!

    assert_equal 'email_daily', user.notifications
    assert_equal true, user.announcements

    put '/account/settings', {:user => {:notifications => "not_valid", :announcements => "false"}}, login(user)

    user.reload

    assert_equal 'email_daily', user.notifications
    assert_equal true, user.announcements

    assert_equal 500, last_response.status
  end

  # password management

  def test_start_reset_password_process
    # post '/subscriptions', :interest => "testing", :subscription_type => "federal_bills"
    # assert_equal 302, last_response.status
    user = new_user!
    old_token = user.reset_token

    Email.should_receive(:deliver!).with("Password Reset Request", user.email, anything, anything)

    post '/account/password/forgot', :email => user.email

    user.reload
    assert_not_equal old_token, user.reset_token

    assert_equal 302, last_response.status
    assert_equal '/login', redirect_path
  end

  def test_start_reset_password_process_with_bad_email
    Email.should_not_receive(:deliver!)
    post '/account/password/forgot', :email => "notvalid@example.com"

    assert_equal 302, last_response.status
    assert_equal '/login', redirect_path
  end

  def test_visit_reset_password_link
    user = new_user!
    reset_token = user.reset_token
    old_password_hash = user.password_hash
    assert !user.should_change_password

    Email.should_receive(:deliver!).with("Password Reset", user.email, anything, anything)

    get '/account/password/reset', :reset_token => reset_token
    user.reload

    assert_not_equal reset_token, user.reset_token
    assert_not_equal old_password_hash, user.password_hash
    assert user.should_change_password

    assert_equal 302, last_response.status
    assert_equal '/login', redirect_path
  end

  def test_visit_reset_password_link_with_no_token
    Email.should_not_receive(:deliver!)

    get '/account/password/reset'
    
    assert_equal 404, last_response.status
  end

  def test_visit_reset_password_link_with_invalid_token
    Email.should_not_receive(:deliver!)

    get '/account/password/reset', :reset_token => "whatever"
    
    assert_equal 404, last_response.status
  end

  def test_change_password
    user = new_user! :password => "test", :password_confirmation => "test", :should_change_password => true

    old_password_hash = user.password_hash
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")
    assert user.should_change_password

    put '/account/password/change', {:old_password => "test", :password => "not-test", :password_confirmation => "not-test"}, login(user)

    user.reload
    assert_not_equal old_password_hash, user.password_hash
    assert !User.authenticate(user, "test")
    assert User.authenticate(user, "not-test")
    assert !user.should_change_password

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_change_password_not_logged_in
    put '/account/password/change', {:old_password => "test", :password => "not-test", :password_confirmation => "not-test"}

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_change_password_wrong_original_password
    user = new_user! :password => "test", :password_confirmation => "test"

    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    put '/account/password/change', {:old_password => "uh oh", :password => "not-test", :password_confirmation => "not-test"}, login(user)

    user.reload
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  def test_change_password_mismatched_new_passwords
    user = new_user! :password => "test", :password_confirmation => "test"

    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    put '/account/password/change', {:old_password => "test", :password => "not-test", :password_confirmation => "not-not-test"}, login(user)

    user.reload
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    # will render directly with user errors
    assert_equal 200, last_response.status
  end

  def test_change_password_disallow_blank_password
    user = new_user! :password => "test", :password_confirmation => "test"

    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "")

    put '/account/password/change', {:old_password => "test", :password => "", :password_confirmation => ""}, login(user)

    user.reload
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "")

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

  # phone settings

  def test_add_phone_number_when_user_has_none
    user = new_user!
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
    user = new_user! :phone => phone1, :phone_confirmed => true, :phone_verify_code => original_verify_code

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
    user = new_user!
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
    user = new_user! :phone => phone, :phone_verify_code => verify_code

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
    user = new_user! :phone => phone, :phone_verify_code => verify_code

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
    user = new_user! :phone => phone, :phone_verify_code => verify_code

    assert !user.phone_confirmed?

    post '/account/phone/confirm', {:phone_verify_code => verify_code.succ}, login(user)

    user.reload
    assert !user.phone_confirmed?
    assert_equal verify_code, user.phone_verify_code

    assert_equal 302, last_response.status
    assert_equal '/account/settings', redirect_path
  end

end
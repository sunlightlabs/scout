require './test/test_helper'

class LoginTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_login
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    post '/login', :login => email, :password => password
    assert_redirect "/"
  end

  def test_login_redirects_back
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    redirect = "/search/federal_bills/anything"

    post '/login', :login => email, :password => password, :redirect => redirect
    assert_redirect redirect
  end

  def test_login_invalid_email
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    post '/login', :login => email.succ, :password => password
    assert_response 200

    assert_match /Invalid/, last_response.body
  end
  
  def test_login_invalid_password
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password

    post '/login', :login => email, :password => password.succ
    assert_response 200

    assert_match /Invalid/, last_response.body
  end

  def test_login_does_not_reset_should_change_password
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password, :should_change_password => true

    assert user.should_change_password

    post '/login', :login => email, :password => password
    assert_redirect '/'

    assert user.reload.should_change_password
  end

  def test_login_with_phone_number
    phone = "+15555551212"
    password = "test"
    user = create :user, phone: phone, password: password, password_confirmation: password

    post '/login', login: phone, password: password
    assert_redirect '/'
  end

  def test_login_with_invalid_phone_number
    phone = "+15555551212"
    password = "test"
    user = create :user, phone: phone, password: password, password_confirmation: password

    post '/login', login: phone.succ, password: password
    assert_response 200

    assert_match /Invalid/, last_response.body
  end

  def test_login_with_unconfirmed_phone_account_fails
    phone = "+15555551212"
    password = "test"
    user = create :phone_user, phone: phone, password: password, password_confirmation: password

    assert !user.confirmed?
    post '/login', login: phone, password: password
    assert_response 200

    assert_match /not been confirmed/i, last_response.body
  end

  def test_login_with_unconfirmed_email_account_fails
    email = "test@example.com"
    password = "test"
    user = create :user, :email => email, :password => password, :password_confirmation => password, :confirmed => false

    assert !user.confirmed?

    post '/login', :login => email, :password => password
    assert_response 200

    assert_match /not been confirmed/i, last_response.body
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

    post '/account/new', {:user => {'email' => email, 'password' => "test", 'password_confirmation' => "test", 'announcements' => false, 'sunlight_announcements' => true}}
    assert_redirect '/account/settings'

    user = User.where(:email => email).first
    assert_not_nil user
    assert User.authenticate(user, "test")
    assert !user.announcements
    assert user.sunlight_announcements
    assert user.confirmed?
  end

  def test_create_user_saves_campaign_source
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    campaign = {'campaign' => {'utm_source' => 'source', 'utm_medium' => 'banner', 'utm_content' => '640', 'utm_campaign' => 'campaign'}}

    post '/account/new', {:user => {'email' => email, 'password' => "test", 'password_confirmation' => "test", 'announcements' => false, 'sunlight_announcements' => true}}, session(campaign)
    assert_redirect '/account/settings'

    user = User.where(:email => email).first
    assert_not_nil user

    assert user.source.is_a?(Hash), "User's source should be a Hash"
    campaign['campaign'].each do |key, value|
      assert_equal value, user.source[key]
    end
  end

  def test_create_user_redirects_back
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    redirect = "/search/federal_bills/anything"

    post '/account/new', {:user => {'email' => email, 'password' => "test", 'password_confirmation' => "test"}, :redirect => redirect}
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

    post '/account/new', {:user => {'email' => "", 'password' => "test", 'password_confirmation' => "test"}}
    assert_response 200

    assert_equal count, User.count

    post '/account/new', {:user => {'password' => "test", 'password_confirmation' => "test"}}
    assert_response 200

    assert_equal count, User.count
  end

  # this has to be done in the controller
  def test_create_user_disallow_blank_passwords
    email = "fake@example.com"
    assert_nil User.where(:email => email).first

    post '/account/new', {:user => {'email' => email, 'password' => "", 'password_confirmation' => ""}}
    assert_response 302
    assert_equal '/login', redirect_path

    assert_nil User.where(:email => email).first
  end


  # password management

  def test_start_reset_password_process
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

end
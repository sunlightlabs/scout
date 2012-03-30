ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'test/unit'

require 'bundler/setup'
require 'rack/test'
require 'scout'

require 'rspec/mocks'

require 'test/test_helper'

set :environment, :test

class AccountsTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods

  def test_start_reset_password_process
    # post '/subscriptions', :interest => "testing", :subscription_type => "federal_bills"
    # assert_equal 302, last_response.status
    user = new_user!
    old_token = user.reset_token

    Email.should_receive(:deliver!).with("Password Reset Request", user.email, anything, anything)

    post '/login/forgot', :email => user.email

    user.reload
    assert_not_equal old_token, user.reset_token

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_start_reset_password_process_with_bad_email
    Email.should_not_receive(:deliver!)
    post '/login/forgot', :email => "notvalid@example.com"

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_visit_reset_password_link
    user = new_user!
    reset_token = user.reset_token
    old_password_hash = user.password_hash
    assert !user.should_change_password

    Email.should_receive(:deliver!).with("Password Reset", user.email, anything, anything)

    get '/account/reset', :reset_token => reset_token
    user.reload

    assert_not_equal reset_token, user.reset_token
    assert_not_equal old_password_hash, user.password_hash
    assert user.should_change_password

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_visit_reset_password_link_with_no_token
    Email.should_not_receive(:deliver!)

    get '/account/reset'
    
    assert_equal 404, last_response.status
  end

  def test_visit_reset_password_link_with_invalid_token
    Email.should_not_receive(:deliver!)

    get '/account/reset', :reset_token => "whatever"
    
    assert_equal 404, last_response.status
  end

  def test_change_password
    user = new_user! :password => "test", :password_confirmation => "test"

    old_password_hash = user.password_hash
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    put '/user/password', {:old_password => "test", :password => "not-test", :password_confirmation => "not-test"}, login(user)

    user.reload
    assert_not_equal old_password_hash, user.password_hash
    assert !User.authenticate(user, "test")
    assert User.authenticate(user, "not-test")

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_change_password_not_logged_in
    put '/user/password', {:old_password => "test", :password => "not-test", :password_confirmation => "not-test"}

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_change_password_wrong_original_password
    user = new_user! :password => "test", :password_confirmation => "test"

    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    put '/user/password', {:old_password => "uh oh", :password => "not-test", :password_confirmation => "not-test"}, login(user)

    user.reload
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    assert_equal 302, last_response.status
    assert_equal '/', redirect_path
  end

  def test_change_password_mismatched_new_passwords
    user = new_user! :password => "test", :password_confirmation => "test"

    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    put '/user/password', {:old_password => "test", :password => "not-test", :password_confirmation => "not-not-test"}, login(user)

    user.reload
    assert User.authenticate(user, "test")
    assert !User.authenticate(user, "not-test")

    # will render directly with user errors
    assert_equal 200, last_response.status
  end

end
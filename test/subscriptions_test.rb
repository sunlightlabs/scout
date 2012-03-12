ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'rack/test'

require 'bundler/setup'
require 'scout'


set :environment, :test


class SubscriptionsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  # helpers

  def app
    Sinatra::Application
  end

  def current_user
    @current_user ||= User.first
  end

  def login
    {"rack.session" => {'user_email' => current_user.email}}
  end


  # begin actual tests

  def test_create_subscriptions_without_login
    post '/subscriptions', :interest => "testing", :subscription_type => "federal_bills"
    assert_equal 302, last_response.status
  end

  def test_create_subscription_on_new_interest
    interests_count = Interest.count
    subscriptions_count = Subscription.count

    post '/subscriptions', {:interest => "testing", :subscription_type => "federal_bills"}, login
    
    assert_equal 200, last_response.status
    assert_equal "application/json", last_response.headers['Content-Type']

    assert_equal interests_count + 1, Interest.count
    assert_equal subscriptions_count + 1, Subscription.count
  end

  def test_homepage
    get '/'
    assert last_response.ok?
  end

  def test_homepage_redirect
    get '/', {}, login
    assert_equal 302, last_response.status
    assert_match /dashboard$/, last_response.headers['Location']
  end
end
require './test/test_helper'

# subscription management for one's account (generic destroy, update, etc.)

class AccountTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  # tragic
  def test_destroy_interest
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    delete "/interest/#{interest.id}", {}, login(user)
    assert_equal 200, last_response.status

    assert_nil Interest.find(interest.id)
    assert_nil Subscription.find(s1.id)
  end

  def test_destroy_interest_not_users_own
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    user2 = create :user, :email => user.email.succ

    delete "/interest/#{interest.id}", {}, login(user2)
    assert_equal 404, last_response.status

    assert_not_nil Interest.find(interest.id)
    assert_not_nil Subscription.find(s1.id)
  end

  def test_destroy_interest_not_logged_in
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    user2 = create :user, :email => user.email.succ

    delete "/interest/#{interest.id}"
    assert_equal 302, last_response.status

    assert_not_nil Interest.find(interest.id)
    assert_not_nil Subscription.find(s1.id)
  end

  def test_update_interest_delivery_type_from_nothing_to_email
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    # no easy way to do this without hardcoding the user notifications field default
    assert_equal "email_immediate", user.notifications
    assert_nil interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "immediate", interest.email_frequency

    put "/interest/#{interest.id}", {:interest => {:notifications => "email_daily"}}, login(user)
    assert_response 200

    user.reload
    interest.reload

    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency
  end

  def test_update_interest_delivery_type_from_email_to_nothing
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search", :notifications => "email_daily"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    # no easy way to do this without hardcoding the user notifications field default
    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    put "/interest/#{interest.id}", {:interest => {:notifications => "none"}}, login(user)
    assert_response 200

    user.reload
    interest.reload

    assert_equal "email_immediate", user.notifications
    assert_equal "none", interest.notifications

    assert_nil interest.mechanism
    assert_nil interest.email_frequency
  end

  def test_update_interest_invalid_delivery_type
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search", :notifications => "email_daily"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    # no easy way to do this without hardcoding the user notifications field default
    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    put "/interest/#{interest.id}", {:interest => {:notifications => "invalid"}}, login(user)
    assert_response 500

    user.reload
    interest.reload

    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency
  end

  def test_update_interest_not_users_own
    user = create :user
    user2 = create :user, :email => user.email.succ
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search", :notifications => "email_daily"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    # no easy way to do this without hardcoding the user notifications field default
    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    put "/interest/#{interest.id}", {:interest => {:notifications => "none"}}, login(user2)
    assert_response 404

    user.reload
    interest.reload

    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency
  end

  def test_update_interest_not_logged_in
    user = create :user
    query = "environment"
    interest = user.interests.create! :in => query, :interest_type => "search", :notifications => "email_daily"
    s1 = interest.subscriptions.create! :subscription_type => "federal_bills", :user_id => user.id, :interest_in => query

    # no easy way to do this without hardcoding the user notifications field default
    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency

    put "/interest/#{interest.id}", {:interest => {:notifications => "none"}}
    assert_redirect "/"

    user.reload
    interest.reload

    assert_equal "email_immediate", user.notifications
    assert_equal "email_daily", interest.notifications

    assert_equal "email", interest.mechanism
    assert_equal "daily", interest.email_frequency
  end

end
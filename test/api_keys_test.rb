require './test/test_helper'

class ApiKeysTestTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods

  def test_create_user_finds_api_key_with_that_email
    email = "user1@example.com"
    key = "abcdef"
    
    ApiKey.create! :email => email, :key => key, :status => "A"
    user = new_user! :email => email

    assert_not_nil user.api_key
    assert user.developer?
  end

  def test_create_api_key_finds_user_with_that_email
    email = "user1@example.com"
    key = "abcdef"
    
    user = new_user! :email => email

    assert_nil user.api_key
    assert !user.developer?
    
    ApiKey.create! :email => email, :key => key, :status => "A"
    user.reload

    assert_not_nil user.api_key
    assert user.developer?
  end

  def test_create_inactive_key_does_not_update_user
    email = "user1@example.com"
    key = "abcdef"
    
    user = new_user! :email => email

    assert_nil user.api_key
    assert !user.developer?
    
    ApiKey.create! :email => email, :key => key, :status => "I"
    user.reload

    assert_nil user.api_key
    assert !user.developer?
  end

  def test_update_key_to_be_active_updates_user
    email = "user1@example.com"
    apikey = "abcdef"
    
    user = new_user! :email => email    
    key = ApiKey.create! :email => email, :key => apikey, :status => "I"
    user.reload

    assert_nil user.api_key
    assert !user.developer?

    key.status = "A"
    key.save!
    user.reload

    assert_not_nil user.api_key
    assert user.developer?
  end

  def test_update_key_by_email_updates_both_users
    email1 = "user1@example.com"
    email2 = "user2@example.com"
    apikey1 = "abcdef"
    user1 = new_user! :email => email1
    user2 = new_user! :email => email2

    key = ApiKey.create! :email => email1, :key => apikey1, :status => "A"
    user1.reload
    assert_equal apikey1, user1.api_key
    assert user1.developer?

    key.email = email2
    key.save!
    user1.reload
    user2.reload

    assert_nil user1.api_key
    assert !user1.developer?
    assert_equal apikey1, user2.api_key
    assert user2.developer?
  end

end
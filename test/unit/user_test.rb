require './test/test_helper'

class UserTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_mass_assignment
    user = create :user

    not_email = "not@example.com"
    not_api_key = "notapikey"

    assert user.confirmed?
    assert_not_equal not_email, user.email
    assert_not_equal not_api_key, user.api_key

    user.attributes = {
        email: not_email,
        api_key: not_api_key,
        confirmed: false
    }

    user.save!
    user.reload

    assert_equal not_email, user.email
    assert_not_equal not_api_key, user.api_key
    assert user.confirmed?
  end

  def test_phone_standardization
    user = build :user
    assert user.valid?

    user = build :user, phone: "1234567890"
    assert user.save
    assert_equal "+11234567890", user.phone

    user = build :user, phone: "(555) (666) (7890)"
    assert user.save
    assert_equal "+15556667890", user.phone

    user = build :user, phone: "fasdhf 555-345-1234"
    assert user.save
    assert_equal "+15553451234", user.phone

    user = build :user, phone: "+76 767-876-1234"
    assert user.save
    assert_equal "+767678761234", user.phone
  end

  def test_phone_invalid_formats
    phone = "1234567890"
    user = build :user, phone: phone
    assert user.valid?

    user.phone = "abcdefgh"
    assert !user.valid?

    user.phone = "123"
    assert !user.valid?

    user.phone = '#{!$%@$#}'
    assert !user.valid?

    user.phone = phone
    assert user.valid?

    # user without phone should also be valid
    user = build :user
    assert_nil user.phone
    assert user.valid?
    user.phone = ""
    assert user.valid?
  end
end
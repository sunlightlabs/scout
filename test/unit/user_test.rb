require './test/test_helper'

class UserTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  # A test class that intentionally should raise exceptions on save,
  # because it mutates an email during before_save.
  class TestUser < User
    # should raise exception
    before_save :mutate!
    def mutate!; email.upcase!; end
  end

  def test_emails_cannot_mutate_before_validation
    email = "Testing@example.com"
    user = TestUser.new email: email

    assert_raise_with_message(RuntimeError, "can't modify frozen String") do
      user.save
    end

    # but it's okay in a non-saving circumstance
    user = User.new email: email
    assert_nothing_raised do
      user.save
      user.email.upcase!
    end
  end

  def test_mass_assignment
    user = create :user

    not_email = "not@example.com"

    assert user.confirmed?
    assert_not_equal not_email, user.email

    user.attributes = {
        email: not_email,
        confirmed: false
    }

    user.save!
    user.reload

    assert_equal not_email, user.email
    assert user.confirmed?
  end

  def test_phone_standardization
    user = build :user
    assert user.valid?

    user = build :user, phone: "6173140966"
    assert user.save
    assert_equal "+16173140966", user.phone

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
    phone = "6173140966" # don't call me please
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
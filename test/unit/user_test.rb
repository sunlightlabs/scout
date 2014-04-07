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

end
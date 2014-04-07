require 'factory_girl'

FactoryGirl.define do

  factory :user do
    sequence(:email) {|n| "fake#{n}@example.com"}
    password "test"
    password_confirmation "test"
    confirmed true # in tests, default it to true for convenience

    factory :service_user do
      service "service1"
      confirmed true
      notifications "email_daily"
      should_change_password false
    end
  end

  factory :tag do
    user
    sequence(:name) {|n| "name#{n}"}

    factory :public_tag do
      self.public true
    end
  end

end
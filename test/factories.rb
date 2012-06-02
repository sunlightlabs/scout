require 'factory_girl'

FactoryGirl.define do

  factory :user do
    sequence(:email) {|n| "fake#{n}@example.com"}
    password "test"
    password_confirmation "test"

    factory :phone_user do
      email nil
      password "test"
      password_confirmation "test"
      phone "+15555551212"
      phone_confirmed false
      confirmed false
      notifications "none"
      should_change_password true
      announcements false
      sunlight_announcements false
    end
  end

  factory :tag do
    user
    sequence(:name) {|n| "name#{n}"}
  end
  
end
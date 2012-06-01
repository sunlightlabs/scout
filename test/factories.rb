require 'factory_girl'

FactoryGirl.define do

  factory :user do
    sequence(:email) {|n| "fake#{n}@example.com"}
    password "test"
    password_confirmation "test"
  end

  factory :tag do
    user
    sequence(:name) {|n| "name#{n}"}
  end
  
end
require 'factory_girl'

FactoryGirl.define do

  factory :user do
    email "fake@example.com"
    password "test"
    password_confirmation "test"
  end

end
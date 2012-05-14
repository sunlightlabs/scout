require 'factory_girl'

FactoryGirl.define do

  factory :user do
    sequence(:email) {|n| "fake#{n}@example.com"}
    password "test"
    password_confirmation "test"
  end

  factory :group do
    user
    name "Group name"
    slug "group-name"
  end

  factory :interest do
    user
    group
    self.in "foia"
    interest_type "search"
    data {
      {:query => self.in}
    }
  end

end
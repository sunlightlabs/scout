require 'factory_girl'

FactoryGirl.define do

  factory :user do
    sequence(:email) {|n| "fake#{n}@example.com"}
    password "test"
    password_confirmation "test"
  end

  factory :interest do
    user
    tags []
    self.in "foia"
    interest_type "search"
    data {
      {:query => self.in}
    }
  end

  factory :subscription do
    user
    interest
    self.interest_in "foia"
    subscription_type "federal_bills"
    data {
      {:query => self.interest_in}
    }
  end

end
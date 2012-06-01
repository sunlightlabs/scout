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

  factory :subscription do
    user

    association :interest, factory: :search_interest
    self.interest_in {self.interest ? self.interest.in : "foia"}

    factory :search_subscription do
      subscription_type "federal_bills"
      data {
        self.interest ? self.interest.data : {:query => self.interest_in}
      }
    end
  end


end
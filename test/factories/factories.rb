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

  factory :interest do
    user
    tags []
    self.in "foia"

    factory :search_interest do
      self.in "foia"
      interest_type "search"
      search_type "all"
      data {
        {:query => self.in}
      }
    end

    factory :bill_interest do
      self.in "hr1234-112"
      interest_type "item"
      item_type "bill"
      data {
        {:bill_id => self.in}
      }
    end
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
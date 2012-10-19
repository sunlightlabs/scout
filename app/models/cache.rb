class Cache
  include Mongoid::Document
  include Mongoid::Timestamps

  field :url
  field :subscription_type
  field :content

  # non-necessary
  field :interest_in

  index({url: 1, subscription_type: 1})
  index created_at: 1
end
class Cache
  include Mongoid::Document
  include Mongoid::Timestamps

  field :url
  field :function, type: Symbol
  field :subscription_type

  field :content

  # used for cache lookup
  index({url: 1, function: 1, subscription_type: 1})

  # used for cache clearing
  index({function: 1, subscription_type: 1})

  # whatever
  index created_at: 1
end
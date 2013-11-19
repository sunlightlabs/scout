# A cached response of a request to a data source.
#
# Used by the subscription manager only.
class Cache
  include Mongoid::Document
  include Mongoid::Timestamps

  # @return [String] the request URL
  field :url
  # @return [Symbol] one of `:search`, `:find` or `:fetch`
  field :function, type: Symbol
  # @return [String,Symbol] either a subscription adapter's lowercase
  #   underscored name or `:document`
  field :subscription_type
  # @return [String] the response body
  field :content

  # Used by `Manager.cache_for`.
  index({url: 1, function: 1, subscription_type: 1})
  # used for cache clearing
  # XXX need to remove `function` for `Manager.uncache!` to use this index
  index({function: 1, subscription_type: 1})
  # whatever XXX unused
  index created_at: 1
end

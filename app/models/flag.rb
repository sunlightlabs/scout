# generic store for system flags
class Flag
  include Mongoid::Document
  include Mongoid::Timestamps

  field :key
  field :value

  index :key
end
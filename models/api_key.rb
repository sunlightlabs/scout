class ApiKey
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :key
  field :email
  field :status
  
  validates_presence_of :key
  validates_presence_of :email
  validates_presence_of :status
  validates_uniqueness_of :key
  validates_uniqueness_of :email
  
  index :key
  index :email
  index :status
end
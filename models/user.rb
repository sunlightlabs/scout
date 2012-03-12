class User
  include Mongoid::Document
  include Mongoid::Timestamps
  
  has_many :subscriptions
  has_many :interests
  
  validates_presence_of :email
  validates_uniqueness_of :email
end
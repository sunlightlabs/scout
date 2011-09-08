class User
  include Mongoid::Document
  include Mongoid::Timestamps
  
  has_many :subscriptions
  has_many :keywords
  
  validates_presence_of :email
  validates_uniqueness_of :email
end
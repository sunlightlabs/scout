class User
  include Mongoid::Document
  include Mongoid::Timestamps
  
  validates_presence_of :email
  validates_uniqueness_of :email
end
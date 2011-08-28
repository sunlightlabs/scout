# transaction log of delivered items

class Delivered
  include Mongoid::Document
  
  field :delivered_at, :type => Time
  field :deliveries, :type => Array
  field :contents
  
  index :delivered_at
  
  validates_presence_of :deliveries
  validates_presence_of :delivered_at
end
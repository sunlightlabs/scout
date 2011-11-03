# transaction log of delivered emails

class Delivered
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :delivered_at, :type => Time
  field :items, :type => Array
  field :subscription_types, :type => Array
  field :keyword
  field :content
  
  index :delivered_at
  
  validates_presence_of :delivered_at
  validates_presence_of :keyword
  validates_presence_of :content
end
# transaction log of delivered emails

class Receipt
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :deliveries, :type => Array

  field :user_id
  field :user_email
  field :user_delivery

  field :subject
  field :content
  field :delivered_at, :type => Time

  scope :for_time, ->(start, ending) {where(created_at: {"$gt" => Time.parse(start).midnight, "$lt" => Time.parse(ending).midnight + 1.day})}
  
  index :delivered_at
  index :user_id
  
  validates_presence_of :delivered_at
  validates_presence_of :content
end
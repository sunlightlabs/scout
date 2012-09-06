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
  
  index :delivered_at
  index :user_id
  index :user_email
  
  validates_presence_of :delivered_at
  validates_presence_of :content

  # if the user is still around, no harm if it's not
  belongs_to :user
end
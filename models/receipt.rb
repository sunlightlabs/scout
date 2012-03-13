# transaction log of delivered emails

class Receipt
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :deliveries, :type => Array

  field :user_email
  field :user_delivery

  field :subject
  field :content
  field :delivered_at, :type => Time
  
  index :delivered_at
  
  validates_presence_of :delivered_at
  validates_presence_of :content

  def to_s
    "[#{user_email}](#{deliveries.size}) #{subject}"
  end

  def subscription_types
    
  end
end
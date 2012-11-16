# transaction log of delivered emails

class Receipt
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :deliveries, :type => Array

  field :user_id
  field :user_email
  field :user_delivery
  field :mechanism

  field :subject
  field :content
  field :delivered_at, :type => Time
  
  index delivered_at: 1
  index user_id: 1
  index user_email: 1
  index mechanism: 1
  
  validates_presence_of :delivered_at
  validates_presence_of :content

  # if the user is still around, no harm if it's not
  belongs_to :user

  scope :for_time, ->(start, ending) {where(delivered_at: {"$gt" => Time.zone.parse(start).midnight, "$lt" => Time.zone.parse(ending).midnight})}
end
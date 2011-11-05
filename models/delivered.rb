# transaction log of delivered emails

class Delivered
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :delivered_at, :type => Time
  field :deliveries, :type => Array
  field :subscription_types, :type => Hash
  field :keyword
  field :subject
  field :content
  
  index :delivered_at
  
  validates_presence_of :delivered_at
  validates_presence_of :keyword
  validates_presence_of :content

  def to_s
    "[#{user_email}] #{keyword} (#{deliveries.size}) - #{subscription_types.map {|type, n| "#{type} (#{n})"}.join ', '}"
  end
end
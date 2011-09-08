# This class is meant to affect the UI *only*, and shouldn't need to appear in subscription logic. 
# Relevant keyword-wide fields (the keyword itself, and possibly in the future a interval of alert) should be duplicated from Keyword to Subscription.
class Keyword
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :keyword
  
  index :keyword
  index :user_id
  
  validates_presence_of :user_id
  validates_presence_of :keyword
  
  belongs_to :user
  
  def subscriptions
    Subscription.where(:keyword => keyword, :user_id => user_id)
  end
end
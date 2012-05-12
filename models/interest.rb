class Interest
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :user
  has_many :subscriptions, :dependent => :destroy
  has_many :seen_items # convenience, subscriptions will do the destroy on them

  # a search string or item ID
  field :in

  # 'search', or the type of item the ID refers to (e.g. 'bill')
  field :interest_type

  # arbitrary metadata
  #   search query - metadata about the search query
  #     (e.g. "query" => "copyright")
  #   item - metadata about the related item 
  #     (e.g. "chamber" => "house", "state" => "NY", "bill_id" => "hr2134-112")
  field :data, :type => Hash, :default => {}

  # per-interest override of notification mechanism
  field :notifications
  validates_inclusion_of :notifications, :in => ["none", "email_daily", "email_immediate", "sms"], :allow_blank => true
  
  index :in
  index :user_id
  index :interest_type
  
  validates_presence_of :user_id
  validates_presence_of :in
  
  def item?
    (interest_type != "search") and (interest_type != "external_feed")
  end

  def feed?
    interest_type == "external_feed"
  end

  def search?
    interest_type == "search"
  end

  def self.public_json_fields
    [
      'created_at', 'updated_at', 'interest_type', 'in'
    ]
  end

  
  # the mechanism this subscription prefers to be delivered as (e.g. email or SMS).
  # for right now, reads right from the user's preferences, but could be changed
  # to be per-interest or per-subscription.
  def mechanism
    preference = self.notifications || user.notifications

    if preference =~ /email/
      "email"
    elsif preference == "sms"
      "sms"
    else
      nil
    end
  end

  def email_frequency
    preference = self.notifications || user.notifications
    if preference == "email_immediate"
      "immediate"
    elsif preference == "email_daily"
      "daily"
    else
      nil
    end
  end

end
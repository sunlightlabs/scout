class Interest
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :user
  has_many :subscriptions, :dependent => :destroy

  # a search string or item ID
  field :in

  # 'search', or the type of item the ID refers to (e.g. 'bill')
  field :interest_type

  # arbitrary metadata
  #   keyword search - TBD
  #   item - metadata about the related item 
  #     (e.g. "chamber" => "house", "state" => "NY", "bill_id" => "hr2134-112")
  field :data, :type => Hash, :default => {}
  
  index :in
  index :user_id
  index :interest_type
  
  validates_presence_of :user_id
  validates_presence_of :in
  
  def item?
    interest_type != "search"
  end

  def search?
    interest_type == "search"
  end

  def self.public_json_fields
    [
      'created_at', 'updated_at', 'data', 'interest_type', 'in'
    ]
  end
end
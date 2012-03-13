class Interest
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # a search string or item ID
  field :in

  # 'search', or the type of item the ID refers to (e.g. 'bill')
  field :interest_type

  # arbitrary metadata
  #   saved search - TBD
  #   item - metadata about the item (e.g. "chamber" => "house")
  field :data, :type => Hash
  
  index :in
  index :user_id
  index :interest_type
  
  validates_presence_of :user_id
  validates_presence_of :in
  
  belongs_to :user
  has_many :subscriptions

  def item?
    interest_type != "search"
  end

  def search?
    interest_type == "search"
  end
end
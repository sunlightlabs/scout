class Group
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug

  belongs_to :user
  has_many :interests
  
  field :name
  slug :name, :scope => :user_id

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :user_id

  # TODO:
  # per-group notifications
  # per-group public/private
end
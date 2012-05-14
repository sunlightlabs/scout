class Group
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug

  belongs_to :user
  has_many :interests
  
  field :name
  slug :name, :scope => :user

  # TODO:
  # per-group notifications
  # per-group public/private
end
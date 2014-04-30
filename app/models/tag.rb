# A user may tag their interests to produce collections.
class Tag
  include Mongoid::Document
  include Mongoid::Timestamps

  # @return [User] the user who created the collection
  belongs_to :user

  # @return [String] the collection's name
  field :name
  # @return [Boolean] whether the collection is public or private
  field :public, type: Boolean, default: false
  # @return [String] the collection's description
  field :description

  index name: 1
  index public: 1
  index user_id: 1

  index({user_id: 1, name: 1})
  index({user_id: 1, public: 1, _id: 1})

  validates_uniqueness_of :name, scope: :user_id

  default_scope desc(:created_at)

  # not a formal relationship, depends on interests keeping their own tag array
  def interests
    user.interests.where tags: name
  end

  after_destroy :remove_from_interests
  # @private
  def remove_from_interests
    interests.each do |interest|
      interest.pull :tags, name
    end
  end

  # @return [Boolean] whether the collection is private
  def private?
    !public?
  end

  def self.normalize(name)
    name.gsub(/[^\w\d\s]/, '').gsub(/\s{2,}/, ' ').strip.downcase
  end

  def self.slugify(name)
    name.strip.tr ' ', '-'
  end

  def self.deslugify(name)
    name.strip.tr '-', ' '
  end
end

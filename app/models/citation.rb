# holds little references to sections of the US Code (at this time)
class Citation
  include Mongoid::Document
  include Mongoid::Timestamps

  field :citation_id
  field :citation_type
  field :description

  # us code specific stuff
  field :usc, type: Hash, default: {}

  validates_presence_of :citation_id

  index citation_id: 1
end
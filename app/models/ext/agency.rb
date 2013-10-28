class Agency
  include Mongoid::Document
  include Mongoid::Timestamps

  field :agency_id, type: String
  field :name
  field :short_name

  index agency_id: 1
  index name: 1
  index short_name: 1

  validates_presence_of :agency_id
  validates_presence_of :name

  default_scope asc(:name)

  def self.agencies_url
    "https://www.federalregister.gov/api/v1/agencies"
  end

  def self.agency_for(result)
    {
      name: result['name'],
      agency_id: result['id'],
      short_name: result['short_name']
    }
  end

end
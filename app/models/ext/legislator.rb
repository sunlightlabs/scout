class Legislator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name
  field :title
  field :bioguide_id

  validates_presence_of :name
  validates_presence_of :bioguide_id
  validates_uniqueness_of :bioguide_id

  index name: 1
  index bioguide_id: 1
  index({title: -1, name: 1})

  default_scope desc(:title).asc(:name)

  def self.url_for_current
    api_key = Environment.config['subscriptions']['sunlight_api_key']
    fields = %w{bioguide_id name_suffix first_name middle_name last_name nickname party state title}

    url = "https://congress.api.sunlightfoundation.com"
    url << "/legislators?per_page=all"
    url << "&apikey=#{api_key}"
    url << "&fields=#{fields.join ','}"
    url
  end

  def self.name_for(legislator)
    first = legislator['nickname'].present? ? legislator['nickname'] : legislator['first_name']
    last = legislator['last_name']
    last << " #{legislator['name_suffix']}" if legislator['name_suffix'].present?
    "#{last}, #{first} [#{legislator['party']}-#{legislator['state']}]"
  end
end
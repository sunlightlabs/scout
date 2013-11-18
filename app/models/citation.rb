# A reference to a section of a codified legal instrument, such as the US Code.
#
# Provides information about a citation if the query terms match a citation.
# Pages are added to `sitemap.xml` for each citation in the US Code.
# @see https://scout.sunlightfoundation.com/search/all/5%20USC%20552
class Citation
  include Mongoid::Document
  include Mongoid::Timestamps

  # @return [String] the citation's identifier, e.g. "usc/5/552"
  field :citation_id
  # @return [String] the citation's type, e.g. "usc"
  field :citation_type
  # @return [String] the citation's description, e.g. "Public information;
  #  agency rules, opinions, orders, records, and proceedings"
  field :description

  # @return [Hash] US code specific information, e.g. section number, title
  #   number and name
  field :usc, type: Hash, default: {}

  validates_presence_of :citation_id

  index citation_id: 1
  index citation_type: 1
end

class Definition
  include Mongoid::Document
  include Mongoid::Timestamps

  field :term
  field :short_definition
  field :long_definition
  field :source
  field :source_url

  validates_presence_of :term
  validates_presence_of :short_definition

  index term: 1
end
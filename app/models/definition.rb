class Definition
  include Mongoid::Document
  include Mongoid::Timestamps

  field :term
  field :short_definition
  field :long_definition_text
  field :long_definition_html
  field :source
  field :source_url

  validates_presence_of :term
  validates_presence_of :short_definition
  validates_presence_of :long_definition_text
  validates_presence_of :long_definition_html

  index term: 1
end
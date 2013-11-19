# A definition of a legal term.
#
# If a term appears in an item's text, and if the subscription adapter's views
# implements the glossary feature, then all occurrences of the term will have a
# tooltip containing the definition.
# @see https://scout.sunlightfoundation.com/item/speech/CREC-2013-11-14-pt1-PgS8027.chunk5/sen-harry-reid-executive-session
class Definition
  include Mongoid::Document
  include Mongoid::Timestamps

  # @return [String] the term
  field :term
  # @return [String] a plain-text short definition
  field :short_definition
  # @return [String] a plain-text long definition
  field :long_definition_text
  # @return [String] an HTML long definition
  field :long_definition_html
  # @return [String] the source of the definition, e.g. "Congress.gov"
  field :source
  # @return [String] the URL to the source of the definition
  field :source_url

  validates_presence_of :term
  validates_presence_of :short_definition
  validates_presence_of :long_definition_text
  validates_presence_of :long_definition_html

  index term: 1
end

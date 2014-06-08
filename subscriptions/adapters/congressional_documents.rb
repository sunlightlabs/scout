module Subscriptions
  module Adapters

    class CongressionalDocuments
      ITEM_TYPE = 'congressional-document'
      SEARCH_ADAPTER = true
      SEARCH_TYPE = true
      # for ordering
      SORT_WEIGHT = 41
      
      ## add later to add citations
      # CITE_TYPE = true
      # SYNCABLE = true
      # MAX_PER_PAGE = 50

      FIELDS = %w{
        document_id document_type document_type_name
        title categories posted_at
        url source_url
      }

      def self.filters
        {
          # options for drop down are set here
        }
      end
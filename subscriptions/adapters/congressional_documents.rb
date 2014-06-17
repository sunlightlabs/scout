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

      # add published_on
      FIELDS = %w{
        document_id version_code congress chamber hearing_title
        urls house_event_id description document_type_name 
        committee_id bill_id bioguide_id chamber publish_date
        witness_type witness_first witness_middle witness_last 
        witness_orgnization occours_at 

      }

      def self.filters
        {
          # options for drop down are set here
        }
      end

      # Return the URL that the given subscription, function, and options map to.
      #
      # subscription: An alert (may not be saved in the database) containing a
      #    search term and any applied filters.
      # function: :check, :initialize, or :search.
      #    :check - The alert is saved in the database, and is being checked for new results.
      #         Limit to a recent window, by date, if possible.
      #    :initialize - The alert has *just* been saved, and is being checked for
      #         whatever results should be considered "seen" to begin with.
      #         Limit to at least 40 results, with no date filter.
      #    :search - A user is doing a search right now, and this is the URL that
      #         will back their results. Limit to 20, and respect the page number
      #         coming in through the `options` hash. Don't limit by date.
      # options:
      #    page: page number of results to search for. Relevant when user is scrolling
      #          through multiple pages of search results.

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          # set to local for tests in config.ymal
          endpoint = "https://congress.api.sunlightfoundation.com"
        end

        url = endpoint
        # replace with new endpoint
        url << "/congressional_documents/search?"

        query = subscription.query['query']
        if query.present? and !["*", "\"*\""].include?(query)
          url << "&query=#{CGI.escape query}"

          url << "&highlight=true"
          url << "&highlight.size=500"
          url << "&highlight.tags=,"
        else

        end
        #citations
        # if subscription.query['citations'].any?
        #   citations = subscription.query['citations'].map {|c| c['citation_id']}
        #   url << "&citing=#{citations.join "|"}"
        #   url << "&citing.details=true"
        # end

        # filters
        # if subscription.data["document_type"].present?
        #   url << "&document_type=#{subscription.data['document_type']}"
        # end

        url << "&order=publish_date"
        url << "&fields=#{FIELDS.join ','}"
        url << "&apikey=#{api_key}"


        # if it's background checking, filter to just the last month for speed
        if function == :check
          url << "&publish_date__gte=#{1.month.ago.strftime "%Y-%m-%d"}"
        end


        url << "&page=#{options[:page]}" if options[:page]
        per_page = (function == :search) ? (options[:per_page] || 20) : 40
        url << "&per_page=#{per_page}"

        url
      end

      # landing page
      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "https://congress.api.sunlightfoundation.com"
        end

        url = "#{endpoint}/documents/search?apikey=#{api_key}"
        url << "&document_id=#{item_id}"
        url << "&fields=#{FIELDS.join ','}"

        url
      end


      def self.title_for(document)
        "Congressional Document: #{document['description'] || document['hearing_title']}"
      end

      def self.slug_for(document)
        title_for document
      end

      def self.search_name(subscription)
        "Congressional Documents"
      end

      def self.item_name(subscription)
        "Congressional Document"
      end

      def self.short_name(number, interest)
        number == 1 ? 'document' : 'documents'
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include results field: #{response.inspect}") unless response['results']

        response['results'].map do |document|
          item_for document
        end
      end

      def self.item_detail_for(response)
        item_for response['results'][0]
      end


      def self.item_for(document)
        return nil unless document

        SeenItem.new(
          item_id: document["document_id"],
########### this is for debug only!!!!!!!!!!
          date: (document["publish_date"] || rand(10).days.ago),
          data: document
        )
      end

    end
  end
end

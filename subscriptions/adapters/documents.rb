module Subscriptions  
  module Adapters

    class Documents

      def self.filters
        {
          # todo: document_type, once more than one is present
        }
      end
      
      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint].dup
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ 
          document_id document_type document_type_name title url posted_at
          source_url gao_id categories description
        }

        url = endpoint

        query = subscription.query['query']
        if query.present?
          url << "/search/documents.json?"
          url << "&q=#{CGI.escape query}"

          url << "&highlight=true"
          url << "&highlight_size=500"
          url << "&highlight_tags=,"
        else
          url << "/documents.json?"
        end

        if subscription.query['citations'].any?
          citations = subscription.query['citations'].map {|c| c['citation_id']}
          url << "&citation=#{citations.join "|"}"
          url << "&citation_details=true"
        end

        url << "&document_type=gao_report"
        url << "&order=posted_at"
        url << "&fields=#{sections.join ','}"
        url << "&apikey=#{api_key}"


        # if it's background checking, filter to just the last month for speed
        if function == :check
          url << "&posted_at__gte=#{1.month.ago.strftime "%Y-%m-%d"}"
        end


        url << "&page=#{options[:page]}" if options[:page]
        per_page = (function == :search) ? (options[:per_page] || 20) : 40
        url << "&per_page=#{per_page}"

        url
      end

      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]

        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ 
          document_type document_type_name title url posted_at
          source_url gao_id categories description
        }

        url = "#{endpoint}/documents.json?apikey=#{api_key}"
        url << "&document_id=#{item_id}"
        url << "&fields=#{sections.join ','}"

        url
      end

      def self.search_name(subscription)
        "GAO Reports"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "GAO reports" : "GAO report"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include documents field: #{response.inspect}") unless response['documents']
        
        response['documents'].map do |document|
          item_for document
        end
      end

      def self.item_detail_for(response)
        item_for response['documents'][0]
      end
      
      
      
      # internal
      
      def self.item_for(document)
        return nil unless document
        Subscriptions::Manager.clean_score document
        
        # not sure why I have to do this...
        if document['posted_at'].is_a?(String)
          document['posted_at'] = Time.parse document['posted_at']
        end

        SeenItem.new(
          item_id: document["document_id"],
          date: document["posted_at"],
          data: document
        )
      end

    end
  end
end
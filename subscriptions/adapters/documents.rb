module Subscriptions  
  module Adapters

    class Documents

      def self.filters
        {
          # todo: document_type, once more than one is present
        }
      end
      
      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']
        
        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end
        
        fields = %w{ 
          document_id document_type document_type_name 
          title categories posted_at
          url source_url 
          gao_report.gao_id gao_report.description
        }

        url = endpoint

        query = subscription.query['query']
        if query.present?
          url << "/documents/search?"
          url << "&query=#{CGI.escape query}"

          url << "&highlight=true"
          url << "&highlight.size=500"
          url << "&highlight.tags=,"
        else
          url << "/documents?"
        end

        if subscription.query['citations'].any?
          citations = subscription.query['citations'].map {|c| c['citation_id']}
          url << "&citing=#{citations.join "|"}"
          url << "&citing.details=true"
        end

        url << "&document_type=gao_report"
        url << "&order=posted_at"
        url << "&fields=#{fields.join ','}"
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
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end
        
        fields = %w{ 
          document_id document_type document_type_name 
          title categories posted_at
          url source_url 
          gao_report.gao_id gao_report.description
        }

        url = "#{endpoint}/documents?apikey=#{api_key}"
        url << "&document_id=#{item_id}"
        url << "&fields=#{fields.join ','}"

        url
      end

      def self.title_for(document)
        "GAO: #{document['title']}"
      end

      def self.slug_for(document)
        title_for document
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
          date: document["posted_at"],
          data: document
        )
      end

    end
  end
end
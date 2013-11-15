module Subscriptions
  module Adapters

    class Documents

      MAX_PER_PAGE = 50

      FIELDS = %w{
        document_id document_type document_type_name
        title categories posted_at
        url source_url
        gao_report.gao_id gao_report.description
        ig_report.inspector ig_report.type ig_report.file_type
      }

      def self.filters
        {
          'document_type' => {
            name: -> type {
              pieces = type.split("_")
              [pieces[0].upcase, pieces[1].capitalize.pluralize].join " "
            }
          }
        }
      end

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end

        url = endpoint
        url << "/documents/search?"

        query = subscription.query['query']
        if query.present? and !["*", "\"*\""].include?(query)
          url << "&query=#{CGI.escape query}"

          url << "&highlight=true"
          url << "&highlight.size=500"
          url << "&highlight.tags=,"
        else

        end

        if subscription.query['citations'].any?
          citations = subscription.query['citations'].map {|c| c['citation_id']}
          url << "&citing=#{citations.join "|"}"
          url << "&citing.details=true"
        end

        # TODO: ditch the limitation
        # url << "&document_type=gao_report"
        if subscription.data["document_type"].present?
          url << "&document_type=#{subscription.data['document_type']}"
        end

        url << "&order=posted_at"
        url << "&fields=#{FIELDS.join ','}"
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

        url = "#{endpoint}/documents?apikey=#{api_key}"
        url << "&document_id=#{item_id}"
        url << "&fields=#{FIELDS.join ','}"

        url
      end

      def self.url_for_sync(options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end

        url = "#{endpoint}/documents?apikey=#{api_key}"
        url << "&fields=#{FIELDS.join ','}"
        url << "&order=posted_at__asc"

        # url << "&document_type=gao_report"

        # per-year sync is made inefficient by two Congress API bugs:
        # https://github.com/sunlightlabs/congress/issues/391
        # https://github.com/sunlightlabs/congress/issues/392

        if options[:since] == "all"
          # ok, get everything

        elsif options[:since] == "current_year"
          url << "&posted_at__gte=#{Time.now.year}-01-01T00:00:00Z"
          # url << "&posted_at__lte=#{Time.now.year}-12-31"

        # can specify a single year (e.g. '2012', '2013')
        elsif options[:since] =~ /^\d+$/
          url << "&posted_at__gte=#{options[:since]}-01-01T00:00:00Z"
          # url << "&posted_at__lte=#{options[:since]}-12-31"

        # default to the last 3 days
        else
          url << "&posted_at__gte=#{3.days.ago.strftime "%Y-%m-%d"}T00:00:00Z"
        end

        url << "&page=#{options[:page]}" if options[:page]
        url << "&per_page=#{MAX_PER_PAGE}"

        url
      end

      def self.title_for(document)
        "#{document['document_type_name']}: #{document['title']}"
      end

      def self.slug_for(document)
        title_for document
      end

      def self.search_name(subscription)
        "Reports"
      end

      def self.item_name(subscription)
        "Report"
      end

      def self.short_name(number, interest)
        number > 1 ? 'reports' : 'report'
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

      # mapping for IG report agency handles to names
      def self.inspector_name(inspector)
        {
          usps: "US Postal Service"
        }[inspector.to_sym]
      end

    end
  end
end
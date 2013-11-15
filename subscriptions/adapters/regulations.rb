module Subscriptions
  module Adapters

    class Regulations

      MAX_PER_PAGE = 50

      FIELDS = %w{
        document_number document_type article_type
        stage title abstract
        posted_at publication_date
        effective_on comments_close_on
        url pdf_url
        agency_names agency_ids
      }

      def self.filters
        {
          "agency" => {
            field: "agency_ids",
            name: -> id {
              if agency = Agency.where(agency_id: id).first
                agency.name
              else
                "Agency ##{id}" # better than crashing
              end
            }
          },
          "stage" => {
            name: -> stage {"#{stage.capitalize} Rule"}
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
        url << "/regulations/search?"

        query = subscription.query['query']
        if query.present? and !["*", "\"*\""].include?(query)
          url << "&query=#{CGI.escape query}"

          url << "&highlight=true"
          url << "&highlight.size=500"
          url << "&highlight.tags=,"
        end

        if subscription.query['citations'].any?
          citations = subscription.query['citations'].map {|c| c['citation_id']}
          url << "&citing=#{citations.join "|"}"
          url << "&citing.details=true"
        end

        url << "&order=posted_at"
        url << "&fields=#{FIELDS.join ','}"
        url << "&apikey=#{api_key}"

        # filters

        ["agency", "stage"].each do |field|
          if subscription.data[field].present?
            url << "&#{filters[field][:field] || field}=#{CGI.escape subscription.data[field]}"
          end
        end

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

        url = "#{endpoint}/regulations?apikey=#{api_key}"
        url << "&document_number=#{item_id}"
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

        url = "#{endpoint}/regulations?apikey=#{api_key}"
        url << "&fields=#{FIELDS.join ','}"
        url << "&order=posted_at__asc"

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

      # given a seen item (bill), return the document URL to fetch
      def self.document_url(item)
        regulation = item.data
        if regulation['document_type'] == 'article'
          "http://unitedstates.sunlightfoundation.com/documents/federal_register/article/#{regulation['document_number']}.htm"
        end
      end

      def self.title_for(regulation)
        regulation['title']
      end

      def self.slug_for(regulation)
        slug = title_for regulation
        if agency = regulation['agency_names'].first
          slug = [agency, slug].join " "
        end
        slug
      end

      def self.search_name(subscription)
        "Federal Regulations"
      end

      def self.item_name(subscription)
        "Regulatory document"
      end

      def self.short_name(number, interest)
        number > 1 ? 'regulations' : 'regulation'
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include results field: #{response.inspect}") unless response['results']

        response['results'].map do |regulation|
          item_for regulation
        end
      end

      def self.item_detail_for(response)
        item_for response['results'][0]
      end



      # internal

      def self.item_for(regulation)
        return nil unless regulation

        SeenItem.new(
          item_id: regulation["document_number"],
          date: regulation["posted_at"],
          data: regulation
        )

      end

    end

  end
end
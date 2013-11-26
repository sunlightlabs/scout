module Subscriptions
  module Adapters

    class CourtOpinions

      # if the adapter supports sync, this must be supplied
      MAX_PER_PAGE = 20

      FIELDS = %w{
        id absolute_url download_url
        download_URL citation
        case_name case_number court court_id date_filed docket_number
      }

      # using:
      #   Federal Appellate, Federal Special, Committee
      # not using:
      #   Federal District, State Appellate, State Supreme
      #   Federal Bankruptcy, Federal Bankruptcy Panel
      COURTS = %w{
        scotus
        ca1 ca2 ca3 ca4 ca5 ca6 ca7 ca8 ca9 ca10 ca11 cadc cafc
        armfor cc uscfc com ccpa cusc tax mc cavc
        eca tecoa fiscr reglrailreorgct cit
        usjc jpml stp
      }

      # this adapter needs to inject http basic auth details into the Curl request
      def self.http(curl)
        curl.http_auth_types = :basic
        curl.username = Environment.config['subscriptions']['courtlistener_username']
        curl.password = Environment.config['subscriptions']['courtlistener_password']
        curl
      end

      # no filters for the time being
      def self.filters
        {

        }
      end

      def self.url_for(subscription, function, options = {})
        endpoint = "https://www.courtlistener.com/api/rest/v1"

        url = endpoint
        url << "/search/?"
        url << "&format=json"
        url << "&fields=#{FIELDS.join ','}"

        query = subscription.query['query']

        if query.present? and !["*", "\"*\""].include?(query)
          url << "&q=#{CGI.escape query}"
        end

        url << "&court=#{COURTS.join ','}"

        # if it's background checking, filter to just the last month for speed
        if function == :check
          url << "&filed_after=#{1.month.ago.strftime "%Y-%m-%d"}"
        else
          url << "&filed_after=2009-01-01"
        end

        # default is dateFiled desc, but make it explicit
        url << "&order_by=dateFiled+desc"

        if options[:page]
          offset = (options[:page].to_i - 1) * 20
          url << "&offset=#{offset}"
        end

        url
      end

      def self.url_for_detail(item_id, options = {})
        endpoint = "https://www.courtlistener.com/api/rest/v1"

        # goes to /opinion endpoint, not /search as expressed in resource_uri
        # todo: can switch to /opinion when court name is available
        #       (and preferably when other inconsistencies worked out)
        url = endpoint
        # url << "/opinion"
        url << "/search"
        url << "/#{item_id}/"
        url << "?format=json"
        url << "&fields=#{FIELDS.join ','}"

        url
      end

      # not synced to a sitemap at this time
      def self.url_for_sync(options = {})
        ""
      end

      def self.search_name(subscription)
        "Court Opinions"
      end

      def self.item_name(subscription)
        "Opinion"
      end

      def self.short_name(number, interest)
        number == 1 ? 'opinion' : 'opinions'
      end

      def self.interest_name(interest)
        interest.data['case_name']
      end

      def self.title_for(opinion)
        opinion['case_name']
      end

      def self.slug_for(opinion)
        opinion['case_name']
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include objects field: #{response.inspect}") unless response['objects']

        response['objects'].map do |opinion|
          item_for opinion
        end
      end

      def self.item_detail_for(response)
        item_for response
      end

      def self.item_for(opinion)
        return nil unless opinion

        date = Time.zone.parse opinion['date_filed']

        # account for differences between /search and /opinion
        if opinion['download_URL']
          opinion['download_url'] = opinion['download_URL']
        end

        if opinion['citation'] and opinion['citation']['case_name']
          opinion['case_name'] = opinion['citation']['case_name']
        end

        SeenItem.new(
          item_id: opinion["id"],
          date: date,
          data: opinion
        )
      end
    end

  end
end
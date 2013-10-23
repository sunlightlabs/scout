module Subscriptions
  module Adapters

    class Speeches

      MAX_PER_PAGE = 50

      def self.filters
        {
          "state" => {
            name: -> code {StateBills.state_map[code]}
          },
          "party" => {
            name: -> party {party_map[party]}
          },
          "chamber" => {
            name: -> chamber {chamber.capitalize}
          },
          "bioguide_id" => {
            name: -> bioguide_id {
              if legislator = Legislator.where(bioguide_id: bioguide_id).first
                legislator.name
              else
                "(Unknown)" # better than crashing
              end
            }
          }
        }
      end

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        endpoint = "http://capitolwords.org/api"

        # speeches don't support citations
        if subscription.query['citations'].any?
          query = subscription.interest_in
        else
          query = subscription.query['query']
        end

        url = "#{endpoint}/text.json?apikey=#{api_key}"

        if query.present? and !["\"*\"", "*"].include?(query)
          url << "&q=#{CGI.escape query}"
        end

        # limit to one speaker?
        if subscription.data['bioguide_id'].present?
          url << "&bioguide_id=#{CGI.escape subscription.data['bioguide_id']}"

        # still keep it only to fields with a speaker (any bioguide_id)
        else
          url << "&bioguide_id=[''%20TO%20*]"
        end

        # filters

        ["state", "party"].each do |field|
          if subscription.data[field].present?
            url << "&#{field}=#{CGI.escape subscription.data[field]}"
          end
        end

        if function == :check
          since = (1.month.ago).strftime("%Y-%m-%d")
          url << "&start_date=#{since}"
        end

        # pagination

        url << "&page=#{options[:page].to_i - 1}" if options[:page]
        url << "&per_page=#{options[:per_page]}" if options[:per_page]

        url << "&sort=date%20desc"

        url
      end

      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        endpoint = "http://capitolwords.org/api"

        url = "#{endpoint}/text.json?apikey=#{api_key}"
        url << "&id=#{item_id}"

        url
      end

      def self.url_for_sync(options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        endpoint = "http://capitolwords.org/api"

        url = "#{endpoint}/text.json?apikey=#{api_key}"

        # count up from date of speech
        url << "&sort=date%20asc"

        # keep it only to fields with a speaker (bioguide_id)
        url << "&bioguide_id=[''%20TO%20*]"


        if options[:since] == "all"
          # ok, get everything (you sure?)

        # can specify a year (e.g. '2009', '2010')
        elsif options[:since] =~ /^\d+$/
          url << "&start_date=#{options[:since]}-01-01"
          url << "&end_date=#{options[:since]}-12-31"

        # default to the last 3 days
        else
          url << "&start_date=#{3.days.ago.strftime "%Y-%m-%d"}"
        end

        url << "&page=#{options[:page].to_i - 1}"
        url << "&per_page=#{MAX_PER_PAGE}"

        url
      end

      def self.title_for(speech)
        speech['title']
      end

      def self.slug_for(speech)
        title = (speech['chamber'] == 'Senate') ? 'Sen' : 'Rep'
        speaker = "#{title}. #{speech['speaker_first']} #{speech['speaker_last']}"
        [speaker, title_for(speech)].join " "
      end

      def self.search_name(subscription)
        "Speeches in Congress"
      end

      def self.item_name(subscription)
        "Speech"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "speeches" : "speech"}"
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include 'results' field: #{response.inspect}") unless response['results']

        #TODO: hopefully get the API changed to allow filtering on only spoken results
        response['results'].map do |result|
          item_for result
        end
      end

      def self.item_detail_for(response)
        item_for response['results'][0]
      end


      # internal

      def self.item_for(result)
        return nil unless result

        result['date'] = Subscriptions::Manager.noon_utc_for result['date']
        result['date_year'] = result['date'].year
        result['date_month']= result['date'].month
        result['date_day'] = result['date'].day

        matches = result['origin_url'].scan(/Pg([\w\d-]+)\.htm$/)
        if matches.any?
          result['page_slug'] = matches.first
        end

        SeenItem.new(
          :item_id => result['id'],
          :date => result['date'],
          :data => result
        )

      end

      def self.party_map
        @party_map ||= {
          "R" => "Republican",
          "D" => "Democrat",
          "I" => "Independent"
        }
      end

    end

  end
end
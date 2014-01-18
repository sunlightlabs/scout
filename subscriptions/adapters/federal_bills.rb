module Subscriptions
  module Adapters

    class FederalBills

      # if the adapter supports sync, this must be supplied
      MAX_PER_PAGE = 50

      FIELDS = %w{
        bill_id bill_type number congress urls
        short_title official_title summary
        last_action actions
        introduced_on last_action_at last_version last_version_on
        sponsor.first_name sponsor.last_name sponsor.nickname
        sponsor.name_suffix sponsor.title sponsor.party sponsor.state
        created_at
      }

      def self.filters
        {
          "stage" => {
            name: -> v {v.split("_").map(&:capitalize).join " "}
          }
        }
      end

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "https://congress.api.sunlightfoundation.com"
        end

        url = endpoint

        url << "/bills/search?"

        query = subscription.query['query']
        federal_bill = Search.federal_bill_for(query) if query

        # if it's a bill filter, will filter on bill_type and number

        if federal_bill.present?
          url << "&bill_type=#{federal_bill[0]}"
          url << "&number=#{federal_bill[1]}"

        elsif query.present? && !["*", "\"*\""].include?(query)
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

        url << "&order=last_version_on"
        url << "&fields=#{FIELDS.join ','}"
        url << "&apikey=#{api_key}"

        # should be unnecessary, we set last_version_on to introduced_on if GPO hasn't published yet
        url << "&last_version_on__exists=true"

        # filters

        if subscription.data["stage"].present?
          stage = subscription.data["stage"]
          if stage == "enacted"
            url << "&history.enacted=true"
          elsif stage == "passed_house"
            url << "&history.house_passage_result=pass"
          elsif stage == "passed_senate"
            url << "&history.senate_passage_result=pass"
          elsif stage == "vetoed"
            url << "&history.vetoed=true"
          elsif stage == "awaiting_signature"
            url << "&history.awaiting_signature=true"
          end
        end

        # if it's background checking, filter to just the last month for speed
        if function == :check
          url << "&last_version_on__gte=#{1.month.ago.strftime "%Y-%m-%d"}"
        end

        if options[:page]
          url << "&page=#{options[:page]}"
        end

        per_page = (function == :search) ? (options[:per_page] || 20) : 40
        url << "&per_page=#{per_page}"

        url
      end

      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "https://congress.api.sunlightfoundation.com"
        end

        url = "#{endpoint}/bills?apikey=#{api_key}"

        # should be unnecessary, we set last_version_on to introduced_on if GPO hasn't published yet
        url << "&last_version_on__exists=true"

        url << "&bill_id=#{item_id}"
        url << "&fields=#{FIELDS.join ','}"

        url
      end

      def self.url_for_sync(options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "https://congress.api.sunlightfoundation.com"
        end

        url = "#{endpoint}/bills?apikey=#{api_key}"
        url << "&fields=#{FIELDS.join ','}"
        url << "&order=introduced_on__asc"


        if options[:since] == "all"
          # ok, get everything

        elsif options[:since] == "current_congress"
          url << "&congress=#{current_congress}"

        # can specify a single congress (e.g. '111', '112')
        elsif options[:since] =~ /^\d+$/
          url << "&congress=#{options[:since]}"

        # TODO: this is bad. (I use current_congress in production.)
        # this will not catch changes in bills introduced before 3 days ago.
        # using updated_at would just mean everything.
        # last_action_at doesn't catch changes that don't have actions associated,
        # but might be the best bet - but the sort would need to change too.
        # it might be best to just not use this mode.
        else
          url << "&introduced_on__gte=#{3.days.ago.strftime "%Y-%m-%d"}"
        end

        url << "&page=#{options[:page]}" if options[:page]
        url << "&per_page=#{MAX_PER_PAGE}"

        url
      end

      # given a seen item (bill), return the document URL to fetch
      def self.document_url(item)
        bill = item.data
        if bill['last_version'] && bill['last_version']['urls']['xml']
          bill_version_id = bill['last_version']['bill_version_id']
          "http://unitedstates.sunlightfoundation.com/documents/bills/#{bill['congress']}/#{bill['bill_type']}/#{bill_version_id}.htm"
        end
      end

      def self.search_name(subscription)
        "Bills in Congress"
      end

      def self.item_name(subscription)
        "Bill"
      end

      def self.short_name(number, interest)
        number == 1 ? 'bill' : 'bills'
      end

      def self.interest_name(interest)
        formatted_code interest.data
      end

      def self.formatted_code(bill)
        code = {
          "hr" => "H.R.",
          "hres" => "H.Res.",
          "hjres" => "H.J.Res.",
          "hconres" => "H.Con.Res.",
          "s" => "S.",
          "sres" => "S.Res.",
          "sjres" => "S.J.Res.",
          "sconres" => "S.Con.Res."
        }[bill['bill_type']]
        "#{code} #{bill['number']}"
      end

      def self.title_for(bill)
        [formatted_code(bill), (bill['short_title'] || bill['official_title'])].join ": "
      end

      def self.slug_for(bill)
        bill['short_title'] || bill['official_title']
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include results field: #{response.inspect}") unless response['results']

        response['results'].map do |bill|
          item_for bill
        end
      end

      # parse response when asking for a single bill - Congress API returns an array of one
      def self.item_detail_for(response)
        return nil unless response
        item_for response['results'][0]
      end

      def self.item_for(bill)
        return nil unless bill

        SeenItem.new(
          item_id: bill["bill_id"],
          date: bill['last_version_on'],
          data: bill
        )
      end

      # e.g. 2009 & 2010 -> 111th congress, 2011 & 2012 -> 112th congress
      def self.current_congress
        congress_for_year current_legislative_year
      end

      def self.congress_for_year(year)
        ((year.to_i + 1) / 2) - 894
      end

      # legislative year - consider Jan 1, Jan 2, and first half of Jan 3 to be last year
      def self.current_legislative_year(now = nil)
        now ||= Time.now
        now = now.in_time_zone # enforce EST

        year = now.year
        if now.month == 1
          if [1, 2].include?(now.day)
            year - 1
          elsif (now.day == 3) && (now.hour < 12)
            year - 1
          else
            year
          end
        else
          year
        end
      end
    end

  end
end
module Subscriptions
  module Adapters

    class StateBills

      # if the adapter supports sync, this must be supplied
      MAX_PER_PAGE = 50

      FIELDS = %w{
        id bill_id subjects state chamber created_at updated_at
        title sources versions session %2Bshort_title
        action_dates
        actions votes
      }

      def self.filters
        {
          "state" => {
            name: -> code {state_map[code.upcase]}
          }
        }
      end

      def self.url_for_sync(options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        endpoint = "http://openstates.org/api/v1"

        url = "#{endpoint}/bills/?apikey=#{api_key}"
        url << "&fields=#{FIELDS.join ','}"

        # for sanity's sake, and to align it with the normal check process,
        # stick to last action, even though created_at or introduced might make more sense
        url << "&sort=last"

        if options[:since] == "all"
          url << "&search_window=all"
        elsif options[:since] == "current_session" # default to current session only
          url << "&search_window=session"
        else # default to just 2 days, it's big
          last_action_since = (options[:start] - 2.days).strftime("%Y-%m-%dT%H:%M:%S")
          url << "&last_action_since=#{last_action_since}"
        end

        url << "&page=#{options[:page]}" if options[:page]
        url << "&per_page=#{MAX_PER_PAGE}"

        url
      end

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        endpoint = "http://openstates.org/api/v1"

        url = "#{endpoint}/bills/?apikey=#{api_key}"
        url << "&fields=#{FIELDS.join ','}"


        # state_bills don't support citations
        if subscription.query['citations'].any?
          query = subscription.interest_in
          return nil unless query.present?
          url << "&q=#{CGI.escape query}"

        else
          query = subscription.query['query']
          # return nil unless query.present?

          # if there's a state bill code, extract it and apply the specific bill_ids__in filter
          if state_bill = Search.state_bill_for(query)
            url << "&bill_id__in=#{CGI.escape state_bill}"
          elsif query.present? and !["*", "\"*\""].include?(query)
            url << "&q=#{CGI.escape query}"
          end
        end


        # filters

        # ignored parameters: 'q', and 'session'

        # state - single string, e.g. "NY"
        if subscription.data['state'].present?
          url << "&state=#{subscription.data['state']}"
        end

        # search_window - single string, e.g. "session:26"
        if subscription.data['search_window'].present?
          url << "&search_window=#{subscription.data['search_window']}"

        # default to an explicit search_window of 'all'
        else
          url << "&search_window=all"
        end

        # chamber - single string, e.g. "upper"
        if subscription.data['chamber'].present?
          url << "&chamber=#{subscription.data['chamber']}"
        end

        # subjects - array of strings, e.g. ["Agriculture and Food", "Public Services"]
        if subscription.data['subjects'].present? and subscription.data['subjects'].any?
          url << subscription.data['subjects'].map {|s| "&subjects=#{s}"}.join("")
        end

        # sponsor_id - single string, e.g. "AKL000023"
        if subscription.data['sponsor_id'].present?
          url << "&sponsor_id=#{subscription.data['sponsor_id']}"
        end

        # type - single string, e.g. "concurrent_resolution"
        if subscription.data['type'].present?
          url << "&type=#{subscription.data['type']}"
        end

        # status - array of strings, e.g. ["passed_upper", "passed_lower"]
        if subscription.data['status'].present? and subscription.data['status'].any?
          url << subscription.data['status'].map {|s| "&status=#{s}"}.join("")
        end

        # order

        url << "&sort=last"


        # for speed's sake, limit check to bills updated in last 2 months

        if function == :check
          last_action_since = (2.months.ago).strftime("%Y-%m-%dT%H:%M:%S")
          url << "&last_action_since=#{last_action_since}"
        end


        # pagination

        if options[:page]
          url << "&page=#{options[:page]}"
        end

        per_page = (function == :search) ? (options[:per_page] || 20) : 50
        url << "&per_page=#{per_page}"


        url
      end

      def self.search_name(subscription)
        "State Bills"
      end

      def self.short_name(number, interest)
        "state #{number > 1 ? "bills" : "bill"}"
      end

      def self.interest_name(interest)
        "#{state_map[interest.data['state'].upcase]} - #{interest.data['bill_id']}"
      end

      def self.title_for(bill)
        "#{bill['bill_id']}, #{state_map[bill['state'].upcase]}: #{(bill['+short_title'] || bill['title'])}"
      end

      def self.slug_for(bill)
        title_for bill
      end

      # item_id in this case is not actually the remote bill_id, since that's not specific enough
      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        endpoint = "http://openstates.org/api/v1"

        # item_id is of the form ":state/:session/:chamber/:bill_id" (URI encoded already)
        url = "#{endpoint}/bills/#{URI.encode item_id.gsub('__', '/').gsub('_', ' ')}/?apikey=#{api_key}"
        url << "&fields=#{FIELDS.join ','}"

        url
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Got string response from Open States:\n\n#{response}") if response.is_a?(String)

        response.map {|bill| item_for bill}
      end

      def self.item_detail_for(bill)
        return nil unless bill
        item_for bill.to_hash
      end

      # internal

      def self.item_for(bill)
        # manually parse all of the dates - so lame, not sure why HTTParty is so bad at the format OpenStates uses

        # created_at and updated_at are UTC, take them directly as such
        ['updated_at', 'created_at'].each do |field|
          bill[field] = bill[field] ? bill[field].to_time : nil
        end

        if bill['actions']
          bill['actions'].each do |action|
            action['date'] = Time.zone.parse(action['date']) if action['date']
          end
        end

        if bill['votes']
          bill['votes'].each do |vote|
            vote['date'] = Time.zone.parse(vote['date']) if vote['date']
          end
        end

        if bill['action_dates']
          bill['action_dates'].keys.each do |key|
            bill['action_dates'][key] = Time.zone.parse(bill['action_dates'][key]) if bill['action_dates'][key]
          end
        end

        # use most recent action for the date, if present (which it should always be)
        if bill['action_dates'] and bill['action_dates']['last']
          date = bill['action_dates']['last']
        else
          date = bill['created_at']
        end

        SeenItem.new(
          item_id: bill['id'],
          date: date,
          data: bill
        )
      end

      # utilities, useful across the app

      def self.state_map
        @state_map ||= {
          "AL" => "Alabama",
          "AK" => "Alaska",
          "AZ" => "Arizona",
          "AR" => "Arkansas",
          "CA" => "California",
          "CO" => "Colorado",
          "CT" => "Connecticut",
          "DE" => "Delaware",
          "DC" => "District of Columbia",
          "FL" => "Florida",
          "GA" => "Georgia",
          "HI" => "Hawaii",
          "ID" => "Idaho",
          "IL" => "Illinois",
          "IN" => "Indiana",
          "IA" => "Iowa",
          "KS" => "Kansas",
          "KY" => "Kentucky",
          "LA" => "Louisiana",
          "ME" => "Maine",
          "MD" => "Maryland",
          "MA" => "Massachusetts",
          "MI" => "Michigan",
          "MN" => "Minnesota",
          "MS" => "Mississippi",
          "MO" => "Missouri",
          "MT" => "Montana",
          "NE" => "Nebraska",
          "NV" => "Nevada",
          "NH" => "New Hampshire",
          "NJ" => "New Jersey",
          "NM" => "New Mexico",
          "NY" => "New York",
          "NC" => "North Carolina",
          "ND" => "North Dakota",
          "OH" => "Ohio",
          "OK" => "Oklahoma",
          "OR" => "Oregon",
          "PA" => "Pennsylvania",
          "PR" => "Puerto Rico",
          "RI" => "Rhode Island",
          "SC" => "South Carolina",
          "SD" => "South Dakota",
          "TN" => "Tennessee",
          "TX" => "Texas",
          "UT" => "Utah",
          "VT" => "Vermont",
          "VA" => "Virginia",
          "WA" => "Washington",
          "WV" => "West Virginia",
          "WI" => "Wisconsin",
          "WY" => "Wyoming"
        }
      end

      def self.openstates_url(bill)
        state = bill['state'].to_s.downcase
        bill_id = bill['bill_id'].tr(' ', '')
        session = bill['session']

        "http://openstates.org/#{state}/bills/#{session}/#{bill_id}/"
      end

    end
  end
end
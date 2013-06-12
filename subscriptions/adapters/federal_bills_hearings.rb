module Subscriptions
  module Adapters

    class FederalBillsHearings

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end

        fields = %w{
          chamber congress
          occurs_at hearing_type
          committee subcommittee
          description room url
        }

        bill_id = subscription.interest_in

        url = "#{endpoint}/hearings?apikey=#{api_key}"
        url << "&bill_ids=#{bill_id}"
        url << "&dc=true"
        url << "&committee__exists=true"

        url << "&fields=#{fields.join ','}"

        url
      end

      def self.search_name(subscription)
        "Upcoming Hearings"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "hearings" : "hearing"}"
      end

      def self.direct_item_url(hearing, interest)
        hearing_url hearing
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['results']

        response['results'].map do |hearing|
          item_for hearing
        end
      end


      def self.item_for(hearing)
        return nil unless hearing

        SeenItem.new(
          item_id: "#{hearing['chamber']}-#{hearing['occurs_at'].to_i}",
          date: hearing['occurs_at'],
          data: hearing
        )
      end

      def self.hearing_url(hearing)
        if hearing['chamber'] == 'senate'
          "http://www.senate.gov/pagelayout/committees/b_three_sections_with_teasers/committee_hearings.htm"
        else
          hearing['url']
        end
      end

    end

  end
end
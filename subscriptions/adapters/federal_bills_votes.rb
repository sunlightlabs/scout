module Subscriptions
  module Adapters

    class FederalBillsVotes
      ITEM_TYPE = 'bill'
      ITEM_ADAPTER = true

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "https://congress.api.sunlightfoundation.com"
        end

        fields = %w{
          roll_id chamber congress year number
          roll_type question result vote_type
          required voted_at breakdown.total
          url
        }

        bill_id = subscription.interest_in

        url = "#{endpoint}/votes?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"
        url << "&bill_id=#{bill_id}"

        url
      end

      def self.search_name(subscription)
        "Votes"
      end

      def self.item_name(subscription)
        "Vote"
      end

      def self.short_name(number, interest)
        number == 1 ? 'vote' : 'votes'
      end

      def self.direct_item_url(vote, interest)
        vote['url']
      end

      # takes parsed response and returns an array where each item is
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['results']

        response['results'].map do |vote|
          item_for vote
        end
      end


      def self.item_for(vote)
        return nil unless vote

        SeenItem.new(
          item_id: vote['roll_id'],
          date: vote['voted_at'],
          data: vote
        )
      end

    end

  end
end
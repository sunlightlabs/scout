module Subscriptions  
  module Adapters

    class FederalBillsVotes
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ chamber session year number roll_id roll_type question result required voted_at vote_type how vote_breakdown.total }

        bill_id = subscription.interest_in
        
        url = "#{endpoint}/votes.json?apikey=#{api_key}"
        url << "&sections=#{sections.join ','}"

        url << "&bill_id=#{bill_id}"
        url << "&how=roll"
        
        url
      end

      def self.search_name(subscription)
        "Votes"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "votes" : "vote"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['votes']
        
        response['votes'].map do |vote|
          item_for vote
        end
      end
      
      
      def self.item_for(vote)
        return nil unless vote

        vote['voted_at'] = Time.zone.parse(vote['voted_at']).utc

        SeenItem.new(
          :item_id => vote['roll_id'],
          :date => vote['voted_at'],
          :data => vote
        )
      end
      
    end
  
  end
end
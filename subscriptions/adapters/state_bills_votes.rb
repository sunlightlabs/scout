module Subscriptions  
  module Adapters

    class StateBillsVotes
      
      def self.url_for(subscription, function, options = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        
        fields = %w{ id bill_id state chamber session votes }
        
        item_id = subscription.interest_in

        # item_id is of the form ":state/:session/:chamber/:bill_id" (URI encoded already)
        url = "#{endpoint}/bills/#{URI.encode item_id.gsub('__', '/').gsub('_', ' ')}/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"

        url
      end

      def self.search_name(subscription)
        "Votes"
      end

      def self.short_name(number, interest)
        number > 1 ? "votes" : "vote"
      end
      
      def self.items_for(response, function, options = {})
        return nil unless response['votes']

        votes = []
        response['votes'].each do |vote|
          votes << item_for(response['id'], vote)
        end
        votes
      end
      

      # private
      
      def self.item_for(bill_id, vote)
        return nil unless vote

        vote['date'] = Time.zone.parse vote['date']

        SeenItem.new(
          item_id: "#{bill_id}-vote-#{vote['date'].to_i}",
          date: vote['date'],
          data: vote
        )
      end
      
    end
  
  end
end
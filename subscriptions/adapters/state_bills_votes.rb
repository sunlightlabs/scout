module Subscriptions  
  module Adapters

    class StateBillsVotes
      
      def self.url_for(subscription, function, options = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        
        fields = %w{ bill_id state chamber session votes }
        
        item_id = subscription.interest_in

        # item_id is of the form ":state/:session/:chamber/:bill_id" (URI encoded already)
        url = "#{endpoint}/bills/#{URI.encode item_id.gsub('__', '/').gsub('_', ' ')}/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"

        url
      end

      def self.description(number, subscription, interest)
        "#{number} #{number > 1 ? "votes" : "votes"}"
      end

      def self.item_path(item)
        "/state_bill/#{URI.encode item.subscription_interest_in}#votes-#{item['data']['date'].to_i}"
      end
      
      def self.items_for(response, function, options = {})
        return nil unless response['votes']
        
        item_id = StateBills.id_for response.to_hash

        votes = []
        response['votes'].each_with_index do |vote, i|
          votes << item_for(item_id, i, vote)
        end
        votes
      end
      

      # private
      
      def self.item_for(item_id, i, vote)
        return nil unless vote

        vote['date'] = vote['date'].to_time

        SeenItem.new(
          :item_id => "#{item_id}-vote-#{i}",
          :date => vote['date'],
          :data => vote
        )
      end
      
    end
  
  end
end
module Subscriptions  
  module Adapters

    class FederalBillsActivity
      
      def self.url_for(subscription, function, options = {})
        api_key = Environment.config['subscriptions']['sunlight_api_key']
        
        if Environment.config['subscriptions']['congress_endpoint'].present?
          endpoint = Environment.config['subscriptions']['congress_endpoint'].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end
        
        fields = %w{ bill_id actions last_action_at }

        bill_id = subscription.interest_in
        
        url = "#{endpoint}/bills?apikey=#{api_key}"
        url << "&bill_id=#{bill_id}"
        url << "&fields=#{fields.join ','}"
        
        url
      end

      def self.search_name(subscription)
        "Official Activity"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "actions" : "action"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['results'] and response['results'].first and response['results'].first['actions']
        
        bill_id = response['results'].first['bill_id']

        actions = []
        response['results'].first['actions'].each do |action|
          # don't alert on vote actions, they are handled separately, by the votes adapter
          # but do show them on the front-end, weird to pretend it's not there
          next if (action['type'] == "vote") and (function != :search)
          
          actions << item_for(bill_id, action)
        end

        actions
      end
      

      def self.item_for(bill_id, action)
        return nil unless action

        # can be either a date or timestamp
        action['acted_at'] = Time.zone.parse action['acted_at']

        SeenItem.new(
          item_id: "#{bill_id}-action-#{action['acted_at'].to_i}",
          date: action['acted_at'],
          data: action
        )
      end
      
    end
  
  end
end
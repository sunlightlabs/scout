module Subscriptions  
  module Adapters

    class FederalBillsActivity
      
      def self.url_for(subscription, function, options = {})
        url_for_bill subscription.interest_in, options
      end

      def self.url_for_bill(bill_id, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id actions last_action_at }
        
        url = "#{endpoint}/bills.json?apikey=#{api_key}"
        url << "&bill_id=#{bill_id}"
        url << "&sections=#{sections.join ','}"
        
        url
      end

      def self.item_path(item)
        "/bill/#{item.subscription_interest_in}#action-#{item['data']['acted_at'].to_i}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['bills'] and response['bills'].first and response['bills'].first['actions']
        
        bill_id = response['bills'].first['bill_id']

        actions = []
        response['bills'].first['actions'].each_with_index do |action, i|
          actions << item_for(bill_id, i, action)
        end
        actions
      end
      

      # private
      
      def self.item_for(bill_id, i, action)
        return nil unless action

        SeenItem.new(
          :item_id => "#{bill_id}-action-#{i}",
          :date => action['acted_at'],
          :data => action
        )
      end
      
    end
  
  end
end
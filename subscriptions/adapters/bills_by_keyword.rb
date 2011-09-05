module Subscriptions  
  module Adapters

    class BillsByKeyword
      
      # public
      
      MAX_ITEMS = 20
      
      def self.url_for(subscription)
        # requires a query string
        return nil unless subscription.keyword.present?
        
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill.bill_id bill.bill_type bill.number bill.short_title bill.official_title bill.introduced_at bill.last_action_at bill.last_action version_code bill_version_id bill.session }
        
        url = "#{endpoint}/search/bill_versions.json?apikey=#{api_key}"
        url << "&per_page=#{MAX_ITEMS}"
        url << "&query=#{query}"
        url << "&order=bill.last_action_at"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true&highlight_size=500"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        return nil unless response['bill_versions']
        
        response['bill_versions'].map do |bv|
          item_for bv
        end
      end
      
      
      # internal
      
      def self.item_for(bill_version)
        
        Subscriptions::Item.new(
          :id => bill_version["bill_version_id"],
          :data => bill_version
        )
          
      end
    end
  
  end
end
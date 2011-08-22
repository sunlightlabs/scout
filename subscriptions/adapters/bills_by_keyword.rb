module Subscriptions  
  module Adapters

    class BillsByKeyword
      
      MAX_ITEMS = 20
      
      def self.url_for(subscription)
        # requires a query string
        return nil unless subscription.data['keyword'].present?
        
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.data['keyword']
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill.bill_id bill.bill_type bill.number bill.short_title bill.official_title bill.introduced_at bill.last_action_at version_code bill_version_id }
        
        url = "#{endpoint}/search/bill_versions.json?apikey=#{api_key}"
        url << "&per_page=#{MAX_ITEMS}"
        url << "&query=#{query}"
        url << "&order=bill.last_action_at"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        items = []
        response['bill_versions'].each do |bv|
          items << item_for(bv)
        end
        items
      end
      
      
      # internal
      
      # returns a hash containing the id, title, and post date of the item
      def self.item_for(bill_version)
        # remove the prefacing 'bill.' (will fix this in RTC)
        data = {
          "bill_id" => bill_version.delete("bill.bill_id"),
          "bill_type" => bill_version.delete("bill.bill_type"),
          "number" => bill_version.delete("bill.number"),
          "short_title" => bill_version.delete("bill.short_title"),
          "official_title" => bill_version.delete("bill.official_title"),
          "introduced_at" => bill_version.delete("bill.introduced_at"),
          "last_action_at" => bill_version.delete("bill.last_action_at")
        }
        data = data.merge bill_version
        
        Subscriptions::Item.new(
          :id => bill_version["bill_version_id"],
          :data => data
        )
          
      end
    end
  
  end
end
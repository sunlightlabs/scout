module Subscriptions  
  module Adapters

    class StateBills
      
      
      def self.initialize!(subscription)
        subscription.memo['last_checked'] = Time.now
        subscription.save!
      end
      
      # don't deliver anything yet
      def self.check!(subscription)
        # pass
      end
      
      
      def self.url_for(subscription, options = {})
        endpoint = "http://openstates.sunlightlabs.com/api/v1"
        
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        updated_since = 2.months.ago.strftime("%Y-%m-%d") # subscription.memo['last_checked'].strftime("%Y-%m-%d")
        
        fields = %w{ bill_id subjects state chamber updated_at title }
        
        url = "#{endpoint}/bills/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"
        url << "&q=#{query}"
        # url << "&updated_since=#{updated_since}"
        url << "&search_window=term"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        items = response.map {|bill| item_for bill}
        items.sort {|i, j| j.data['updated_at'] <=> i.data['updated_at'] }
      end
      
      
      # internal
      
      def self.item_for(bill)
        bill['updated_at'] = Time.parse bill['updated_at']
        
        Subscriptions::Item.new(
          :id => bill["bill_id"],
          :date => bill["updated_at"],
          :data => bill
        )
      end
      
    end
    
  end
end
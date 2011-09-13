module Subscriptions  
  module Adapters

    class StateBills
      
      MAX_ITEMS = 20
      
      def self.initialize!(subscription)
        # don't do anything
      end
      
      def self.check!(subscription)
        
        
        
      end
      
      def self.search(subscription)
        Subscriptions::Manager.poll subscription, :search
      end
        
      
      # function is one of :search, :check
      def self.url_for(subscription, function)
        endpoint = "http://openstates.org/api/v1"
        
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        # updated_since = subscription.memo['last_checked'].strftime("%Y-%m-%dT%H:%M:%S")
        
        fields = %w{ bill_id subjects state chamber updated_at title sources versions session }
        
        url = "#{endpoint}/bills/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"
        url << "&q=#{query}"
        url << "&sort=updated_at"
        url << "&search_window=term"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        response.first(MAX_ITEMS).map {|bill| item_for bill}
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
module Subscriptions  
  module Adapters

    class StateBills
      
      MAX_ITEMS = 20
      
      def self.initialize!(subscription)
        # don't do anything!
      end
      
      def self.check!(subscription) 
        Subscriptions::Manager.poll(subscription, :check).each do |item|
          Subscriptions::Manager.schedule_delivery! subscription, item
        end
      end
      
      def self.search(subscription)
        Subscriptions::Manager.poll subscription, :search
      end
        
      
      def self.url_for(subscription, function)
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        fields = %w{ bill_id subjects state chamber updated_at title sources versions session }
        
        url = "#{endpoint}/bills/?apikey=#{api_key}"
        
        if function == :search
          url << "&fields=#{fields.join ','}"
          url << "&q=#{query}"
          url << "&sort=updated_at"
          url << "&search_window=term"
          
        elsif function == :check
          updated_since = subscription.last_checked_at.strftime("%Y-%m-%dT%H:%M:%S")
          
          url << "&fields=#{fields.join ','}"
          url << "&q=#{query}"
          url << "&search_window=term"
          url << "&updated_since=#{updated_since}"
        end
        
        url
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        response.first(MAX_ITEMS).map {|bill| item_for bill}
      end
      
      
      # internal
      
      def self.item_for(bill)
        bill['updated_at'] = bill['updated_at'] ? Time.parse(bill['updated_at']) : nil
        
        slug = bill['bill_id'].downcase.tr " ", "-"
        id = "#{bill['state']}-#{slug}"
        
        Subscriptions::Result.new(
          :id => id,
          :date => bill["updated_at"],
          :data => bill
        )
      end
      
    end
    
  end
end
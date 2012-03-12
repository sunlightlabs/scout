module Subscriptions  
  module Adapters

    class StateBills
      
      def self.url_for(subscription, function, options = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        fields = %w{ bill_id subjects state chamber updated_at title sources versions session }
        
        url = "#{endpoint}/bills/?apikey=#{api_key}"
        
        if function == :search or function == :initialize
          url << "&fields=#{fields.join ','}"
          url << "&q=#{query}"
          url << "&search_window=term"
          url << "&sort=updated_at"
          
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
      def self.items_for(response, function, options = {})
        per_page = 20

        # OpenStates API does not have server-side pagination - so we do it here
        page = options[:page] || 1
        beginning = per_page * (page - 1) # index of first item
        ending = (beginning + per_page) - 1  # index of last item

        # for searching, only return the first "page" of items, otherwise, handle any and all
        items = (function == :search) ? response[beginning..ending] : response

        items.map {|bill| item_for bill}
      end
      
      
      # internal
      
      def self.item_for(bill)
        bill['updated_at'] = bill['updated_at'] ? Time.parse(bill['updated_at']) : nil
        
        slug = bill['bill_id'].downcase.tr " ", "-"
        id = "#{bill['state']}-#{slug}"
        
        SeenItem.new(
          :item_id => id,
          :date => bill["updated_at"],
          :data => bill
        )
      end
      
    end
    
  end
end
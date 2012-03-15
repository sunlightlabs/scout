module Subscriptions  
  module Adapters

    class StateBills
      
      def self.url_for(subscription, function, options = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        fields = %w{ bill_id subjects state chamber updated_at title sources versions session %2Bshort_title }
        
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

      def self.item_path(item)
        "/state_bill/#{item.item_id}"
      end

      # item_id in this case is not actually the remote bill_id, since that's not specific enough
      def self.url_for_detail(item_id, data = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        
        fields = %w{ bill_id state chamber updated_at title sources actions votes session versions %2Bshort_title }
        
        # item_id is of the form ":state/:session/:chamber/:bill_id" (URI encoded already)
        url = "#{endpoint}/bills/#{URI.encode item_id.gsub('__', '/').gsub('_', ' ')}/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"

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
        items = (function == :search) ? (response[beginning..ending] || []) : response

        items.map {|bill| item_for bill}
      end

      def self.description(number, subscription, interest)
        "#{number} #{number > 1 ? "bills" : "bill"} in the states"
      end
      
      def self.item_detail_for(bill)
        item_for bill.to_hash
      end
      
      # internal
      
      def self.item_for(bill)
        # manually parse all of the dates - so lame, not sure why HTTParty is so bad at the format OpenStates uses
        bill['updated_at'] = bill['updated_at'] ? noon_utc_for(bill['updated_at']) : nil

        if bill['actions']
          bill['actions'].each do |action|
            action['date'] = noon_utc_for(action['date']) if action['date']
          end
        end

        if bill['votes']
          bill['votes'].each do |vote|
            vote['date'] = noon_utc_for(vote['date']) if vote['date']
          end
        end
        
        bill_id = URI.encode bill['bill_id']
        session = URI.encode bill['session']
        chamber = URI.encode bill['chamber']
        state = URI.encode bill['state']

        # save the item ID as a piece of the URL we can plug back into the OS API later
        SeenItem.new(
          :item_id => [state, session, chamber, bill_id].join("__"),
          :date => bill["updated_at"],
          :data => bill
        )
      end

      # cast dates with an unknown time zone to noon UTC, to make sure at least the day is always correct
      def self.noon_utc_for(date)
        date.to_time.midnight + 12.hours
      end
      
    end
    
  end
end
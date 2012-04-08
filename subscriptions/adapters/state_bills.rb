module Subscriptions  
  module Adapters

    class StateBills
      
      def self.url_for(subscription, function, options = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        fields = %w{ bill_id subjects state chamber created_at updated_at title sources versions session %2Bshort_title }
        
        url = "#{endpoint}/bills/?apikey=#{api_key}"
        
        url << "&fields=#{fields.join ','}"
        url << "&q=#{query}"
        url << "&search_window=all"
        
        if subscription.data['state'].present?
          url << "&state=#{subscription.data['state']}"
        end

        if function == :search or function == :initialize
          url << "&sort=created_at"
        elsif function == :check
          updated_since = subscription.last_checked_at.strftime("%Y-%m-%dT%H:%M:%S")
          url << "&updated_since=#{updated_since}"
        end

        url
      end

      def self.search_name(subscription)
        "#{subscription.data['state'] || "State"} Bills"
      end

      def self.short_name(number, subscription, interest)
        "#{subscription.data['state'] || "state"} #{number > 1 ? "bills" : "bill"}"
      end

      # item_id has already been URI encoded
      def self.item_path(item)
        "/state_bill/#{item.item_id}"
      end

      # another way of getting the same URL, but from within an interest
      def self.interest_path(interest)
        "/state_bill/#{URI.encode interest.in}"
      end

      def self.interest_name(interest)
        "#{interest.data['bill_id']} (#{interest.data['state'].upcase})"
      end

      # item_id in this case is not actually the remote bill_id, since that's not specific enough
      def self.url_for_detail(item_id, data = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = config[:subscriptions][:sunlight_api_key]
        
        fields = %w{ bill_id state chamber created_at updated_at title sources actions votes session versions %2Bshort_title }
        
        # item_id is of the form ":state/:session/:chamber/:bill_id" (URI encoded already)
        url = "#{endpoint}/bills/#{URI.encode item_id.gsub('__', '/').gsub('_', ' ')}/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"

        url
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return if response.is_a?(String)
        
        # OpenStates API does not have server-side pagination - so we do it here
        per_page = options[:per_page] || 20
        page = options[:page] || 1
        beginning = per_page * (page - 1) # index of first item
        ending = (beginning + per_page) - 1  # index of last item

        # for searching, only return the first "page" of items, otherwise, handle any and all
        items = (function == :search) ? (response[beginning..ending] || []) : response

        items.map {|bill| item_for bill}
      end

      def self.item_detail_for(bill)
        item_for bill.to_hash
      end
      
      # internal
      
      def self.item_for(bill)
        # manually parse all of the dates - so lame, not sure why HTTParty is so bad at the format OpenStates uses

        # updated_at is UTC, take it directly as such
        bill['updated_at'] = bill['updated_at'] ? bill['updated_at'].to_time : nil

        if bill['actions']
          bill['actions'].each do |action|
            action['date'] = Time.parse(action['date']) if action['date']
          end
        end

        if bill['votes']
          bill['votes'].each do |vote|
            vote['date'] = Time.parse(vote['date']) if vote['date']
          end
        end

        # save the item ID as a piece of the URL we can plug back into the OS API later
        SeenItem.new(
          :item_id => id_for(bill),
          :date => bill["created_at"],
          :data => bill
        )
      end

      def self.id_for(bill)
        bill_id = URI.encode bill['bill_id']
        session = URI.encode bill['session']
        chamber = URI.encode bill['chamber']
        state = URI.encode bill['state']
        [state, session, chamber, bill_id].join("__")
      end

      # cast dates with an unknown time zone to noon UTC, to make sure at least the day is always correct
      def self.noon_utc_for(date)
        date.to_time.midnight + 12.hours
      end
      
    end
    
  end
end
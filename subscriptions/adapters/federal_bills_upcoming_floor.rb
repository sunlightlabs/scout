module Subscriptions  
  module Adapters

    class FederalBillsUpcomingFloor
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:congress_endpoint].present?
          endpoint = config[:subscriptions][:congress_endpoint].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end
        
        fields = %w{ source_type bill_id chamber url legislative_day }

        bill_id = subscription.interest_in
        
        url = "#{endpoint}/upcoming_bills?apikey=#{api_key}"
        url << "&bill_id=#{bill_id}"
        url << "&fields=#{fields.join ','}"
        
        url
      end

      def self.search_name(subscription)
        "On the Floor"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "floor notices" : "floor notice"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['results']
        
        response['results'].map do |upcoming|
          item_for upcoming
        end
      end
      
      
      def self.item_for(upcoming)
        return nil unless upcoming

        SeenItem.new(
          item_id: "#{upcoming['legislative_day']}-#{upcoming['chamber']}",
          date: upcoming['legislative_day'],
          data: upcoming
        )
      end
      
    end
  
  end
end
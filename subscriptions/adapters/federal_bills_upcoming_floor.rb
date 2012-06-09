module Subscriptions  
  module Adapters

    class FederalBillsUpcomingFloor
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ source_type bill_id chamber permalink legislative_day }

        bill_id = subscription.interest_in
        
        url = "#{endpoint}/upcoming_bills.json?apikey=#{api_key}"
        url << "&bill_id=#{bill_id}"
        url << "&sections=#{sections.join ','}"
        
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
        return nil unless response['upcoming_bills']
        
        response['upcoming_bills'].map do |upcoming|
          item_for upcoming
        end
      end
      
      
      def self.item_for(upcoming)
        return nil unless upcoming

        upcoming['legislative_day'] = Subscriptions::Manager.noon_utc_for upcoming['legislative_day']

        SeenItem.new(
          :item_id => "#{upcoming['legislative_day'].strftime "%Y%m%d"}-#{upcoming['chamber']}",
          :date => upcoming['legislative_day'],
          :data => upcoming
        )
      end
      
    end
  
  end
end
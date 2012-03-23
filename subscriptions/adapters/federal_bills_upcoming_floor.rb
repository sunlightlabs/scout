module Subscriptions  
  module Adapters

    class FederalBillsUpcomingFloor
      
      def self.url_for(subscription, function, options = {})
        url_for_upcoming subscription.interest_in, options
      end

      def self.url_for_upcoming(bill_id, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ source_type bill_id chamber permalink legislative_day }
        
        url = "#{endpoint}/upcoming_bills.json?apikey=#{api_key}"
        url << "&bill_id=#{bill_id}"
        url << "&sections=#{sections.join ','}"
        
        url
      end

      def self.description(number, subscription, interest)
        "#{number} #{number > 1 ? "notices" : "notice"} of upcoming floor activity"
      end

      def self.short_name(number, subscription, interest)
        "#{number > 1 ? "floor notices" : "floor notice"}"
      end

      def self.item_path(item)
        "/bill/#{item.subscription_interest_in}#upcoming-#{item['data']['legislative_day'].strftime("%Y%m%d")}-#{item['data']['chamber']}"
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

        upcoming['legislative_day'] = noon_utc_for upcoming['legislative_day']

        SeenItem.new(
          :item_id => upcoming['permalink'] || "#{upcoming['legislative_day'].strftime "%Y%m%d"}-#{upcoming['chamber']}",
          :date => upcoming['legislative_day'],
          :data => upcoming
        )
      end

      # helper function to straighten dates into UTC times (necessary for serializing to BSON, sigh)
      def self.noon_utc_for(date)
        time = date.to_time
        time.getutc + (12-time.getutc.hour).hours
      end
      
    end
  
  end
end
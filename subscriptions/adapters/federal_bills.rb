module Subscriptions  
  module Adapters

    class FederalBills
      
      def self.search(subscription, options = {})
        Subscriptions::Manager.poll subscription, :search, options
      end
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id bill_type number short_title official_title introduced_at last_action_at last_action last_version.version_code last_version.bill_version_id session last_version.urls.pdf last_version.urls.xml last_version.issued_on }

        per_page = (function == :search) ? 20 : 40
        
        url = "#{endpoint}/search/bills.json?apikey=#{api_key}"
        url << "&per_page=#{per_page}"
        url << "&query=#{query}"
        url << "&order=last_version_on"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true&highlight_size=500"
        url << "&highlight_tags=,"

        if options[:page]
          url << "&page=#{options[:page]}"
        end
        
        url
      end

      def self.find_url(item_id)
        api_key = config[:subscriptions][:sunlight_api_key]
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id bill_type number short_title official_title introduced_at last_action_at last_action last_version.version_code last_version.bill_version_id session last_version.urls.pdf last_version.urls.xml last_version.issued_on }

        url = "#{endpoint}/bills.json?apikey=#{api_key}"
        url << "&bill_id=#{item_id}"
        url << "&sections=#{sections.join ','}"

        url
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['bills']
        
        response['bills'].map do |bv|
          item_for bv
        end
      end
      
      
      def self.item_for(bill)
        bill = bill['bills'][0] if bill['bills'] # accept either the original response or one of the results

        bill['last_version']['issued_on'] = noon_utc_for bill['last_version']['issued_on']
        
        Subscriptions::Result.new(
          :id => bill["bill_id"],
          :date => bill['last_version']["issued_on"],
          :data => bill
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
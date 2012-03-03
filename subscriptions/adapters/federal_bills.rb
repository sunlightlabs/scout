module Subscriptions  
  module Adapters

    class FederalBills
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id bill_type number short_title latest_upcoming official_title introduced_at last_action_at last_action session last_version }

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
        
        sections = %w{ bill_id bill_type number session short_title official_title introduced_at last_action_at last_action last_version 
          summary sponsor cosponsors_count latest_upcoming actions
          }

        url = "#{endpoint}/bills.json?apikey=#{api_key}"
        url << "&bill_id=#{item_id}"
        url << "&sections=#{sections.join ','}"

        url
      end

      # display name for the item as keyword
      def self.item_name(item)
        code = {
          "hr" => "H.R.",
          "hres" => "H.Res.",
          "hjres" => "H.J.Res.",
          "hcres" => "H.Con.Res.",
          "s" => "S.",
          "sres" => "S.Res.",
          "sjres" => "S.J.Res.",
          "scres" => "S.Con.Res."
        }[item['data']['code']]
        "#{code} #{number}"
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
        return nil unless bill

        date = nil
        if bill['last_version']
          bill['last_version']['issued_on'] = noon_utc_for bill['last_version']['issued_on']
          date = bill['last_version']['issued_on']
        else
          date = bill['last_action_at']
        end

        if bill['latest_upcoming']
          bill['latest_upcoming'].each do |upcoming|
            upcoming['legislative_day'] = noon_utc_for upcoming['legislative_day']
          end
        end
        
        Subscriptions::Result.new(
          :id => bill["bill_id"],
          :date => date,
          :data => bill,

          # reference to a URL to find more details on this object, for debugging purposes
          :url => find_url(bill["bill_id"])
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
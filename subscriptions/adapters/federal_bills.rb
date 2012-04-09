module Subscriptions  
  module Adapters

    class FederalBills
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id bill_type number short_title summary latest_upcoming official_title introduced_at last_action_at last_action session last_version }

        per_page = (function == :search) ? (options[:per_page] || 20) : 40

        url = "#{endpoint}/search/bills.json?apikey=#{api_key}"
        url << "&query=#{query}"
        url << "&order=last_version_on"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true"
        url << "&highlight_size=500"
        url << "&highlight_tags=,"

        if options[:page]
          url << "&page=#{options[:page]}"
        end

        url << "&per_page=#{per_page}"
        
        url
      end

      def self.url_for_detail(item_id, data = {})
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

      def self.search_name(subscription)
        "Bills in Congress"
      end

      def self.short_name(number, subscription, interest)
        "#{number > 1 ? "bills" : "bill"}"
      end

      def self.item_path(item)
        "/bill/#{item.item_id}"
      end

      # another way of getting the same URL, but from within an interest
      def self.interest_path(interest)
        "/bill/#{interest.in}"
      end

      def self.interest_name(interest)
        code = {
          "hr" => "H.R.",
          "hres" => "H.Res.",
          "hjres" => "H.J.Res.",
          "hcres" => "H.Con.Res.",
          "s" => "S.",
          "sres" => "S.Res.",
          "sjres" => "S.J.Res.",
          "scres" => "S.Con.Res."
        }[interest.data['bill_type']]
        "#{code} #{interest.data['number']}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['bills']
        
        response['bills'].map do |bv|
          item_for bv
        end
      end

      # parse response when asking for a single bill - RTC still returns an array of one
      def self.item_detail_for(response)
        item_for response['bills'][0]
      end
      
      # internal

      def self.item_for(bill)
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
        
        SeenItem.new(
          :item_id => bill["bill_id"],
          :date => date,
          :data => bill
        )
      end
      
      # helper function to straighten dates into UTC times (necessary for serializing to BSON, sigh)
      def self.noon_utc_for(date)
        date.to_time.midnight + 12.hours
      end
      
    end
  
  end
end
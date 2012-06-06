module Subscriptions  
  module Adapters

    class FederalBills

      def self.filters
        {
          "stage" => {
            name: -> v {v.split("_").map(&:capitalize).join " "}
          }
        }
      end

      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id bill_type number short_title summary last_version_on latest_upcoming official_title introduced_at last_action_at last_action session last_version }

        url = "#{endpoint}/search/bills.json?apikey=#{api_key}"
        url << "&order=last_version_on"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true"
        url << "&highlight_size=500"
        url << "&highlight_tags=,"


        # filters

        if subscription.data['query_type'] == 'simple'
          url << "&query=#{query}"
        else
          url << "&q=#{query}"
        end

        # search-only filters
        if function == :search
          if subscription.data["session"].present?
            url << "&session=#{URI.encode subscription.data["session"]}"
          end
        end

        if subscription.data["stage"].present?
          stage = subscription.data["stage"]
          if stage == "enacted"
            url << "&enacted=true"
          elsif stage == "passed_house"
            url << "&house_passage_result=pass"
          elsif stage == "passed_senate"
            url << "&senate_passage_result=pass"
          elsif stage == "vetoed"
            url << "&vetoed=true"
          elsif stage == "awaiting_signature"
            url << "&awaiting_signature=true"
          end
        end

        if options[:page]
          url << "&page=#{options[:page]}"
        end

        per_page = (function == :search) ? (options[:per_page] || 20) : 40
        url << "&per_page=#{per_page}"
        
        url
      end

      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]

        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill_id bill_type number session short_title official_title introduced_at last_action_at last_action last_version 
          summary sponsor cosponsors_count latest_upcoming actions last_version_on
          }

        url = "#{endpoint}/bills.json?apikey=#{api_key}"
        url << "&bill_id=#{item_id}"
        url << "&sections=#{sections.join ','}"

        url
      end

      def self.search_name(subscription)
        "Bills in Congress"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "bills" : "bill"}"
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

      def self.interest_subtitle(interest)
        interest.data['short_title'] || interest.data['official_title']
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
        return nil unless response
        item_for response['bills'][0]
      end
      
      # internal

      def self.item_for(bill)
        return nil unless bill

        bill['last_version_on'] = Subscriptions::Manager.noon_utc_for bill['last_version_on']

        if bill['last_version']
          bill['last_version']['issued_on'] = Subscriptions::Manager.noon_utc_for bill['last_version']['issued_on']
        end

        
        SeenItem.new(
          :item_id => bill["bill_id"],
          :date => bill['last_version_on'], # order by the last version published
          :data => bill
        )
      end
      
    end
  
  end
end
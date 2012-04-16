module Subscriptions
  module Adapters

    class Speeches
      
      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        
        query = URI.escape subscription.interest_in
        
        endpoint = "http://capitolwords.org/api"
        
        url = "#{endpoint}/text.json?apikey=#{api_key}"
        url << "&phrase=#{query}"
        url << "&sort=date%20desc"

        if options[:page]
          url << "&page=#{options[:page].to_i - 1}"
        end
        
        url
      end

      def self.url_for_detail(item_id, data = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        endpoint = "http://capitolwords.org/api"
        
        url = "#{endpoint}/text.json?apikey=#{api_key}"
        url << "&id=#{item_id}"
        
        url
      end

      def self.search_name(subscription)
        "Speeches in Congress"
      end
      
      def self.short_name(number, subscription, interest)
        "#{number > 1 ? "speeches" : "speech"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['results']
        
        #TODO: hopefully get the API changed to allow filtering on only spoken results
        results = response['results'].select {|r| r['bioguide_id']}.map do |result|
          item_for result
        end

        per_page = options[:per_page] || 20
        
        results[0...per_page]
      end
      
      def self.item_detail_for(response)
        item_for response['results'][0]
      end
      
      
      # internal
      
      def self.item_for(result)
        date = result['date']
        result['date'] = noon_utc_for result['date']
        result['date_year'] = date.year
        result['date_month']= date.month
        result['date_day'] = date.day
        
        matches = result['origin_url'].scan(/Pg([\w\d-]+)\.htm$/)
        if matches.any?
          result['page_slug'] = matches.first
        end
        
        SeenItem.new(
          :item_id => result['id'],
          :date => result['date'],
          :data => result
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
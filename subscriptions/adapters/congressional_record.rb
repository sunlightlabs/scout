module Subscriptions
  module Adapters

    class CongressionalRecord
      
      # MAX_ITEMS = 20
      
      
      # 1) does the initial poll, 
      # 2) stores every item ID as seen 
      def self.initialize!(subscription)
        Subscriptions::Manager.poll(subscription, :initialize).each do |item|
          SeenId.create! :subscription_id => subscription.id, :item_id => item.id
        end
      end
      
      # 1) does a poll
      # 2) stores any items as yet unseen by this subscription in seen_ids
      # 3) stores any items as yet unseen by this subscription in the delivery queue
      def self.check!(subscription)
        if results = Subscriptions::Manager.poll(subscription, :check)
          results.each do |item|
            unless SeenId.where(:subscription_id => subscription.id, :item_id => item.id).first
              SeenId.create! :subscription_id => subscription.id, :item_id => item.id
              Subscriptions::Manager.schedule_delivery! subscription, item
            end
          end
        end
      end
      
      # non-destructive, searches for example results
      def self.search(subscription)
        Subscriptions::Manager.poll subscription, :search
      end
      
      # ignore function, all polls look for the same information
      def self.url_for(subscription, function)
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        endpoint = "http://capitolwords.org/api"
        
        url = "#{endpoint}/text.json?apikey=#{api_key}"
        url << "&phrase=#{query}"
        url << "&sort=date%20desc"
        
        url
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        return nil unless response['results']
        
        #TODO: hopefully get the API changed to allow filtering on only spoken results
        response['results'].select {|r| r['bioguide_id']}.map do |result|
          item_for result
        end
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
        
        Subscriptions::Result.new(
          :id => "#{result["origin_url"]}-#{result['order']}",
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
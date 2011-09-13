module Subscriptions  
  module Adapters

    class FederalBills
      
      MAX_ITEMS = 20
      
      
      # 1) does the initial poll, 
      # 2) stores every item ID as seen 
      # 3) marks the subscription as initialized
      def self.initialize!(subscription)
        Subscriptions::Manager.poll(subscription, :initialize).each do |item|
          SeenId.create! :subscription_id => subscription.id, :item_id => item.id
        end
      end
      
      # 1) does a poll
      # 2) stores any items as yet unseen by this subscription in seen_ids
      # 3) stores any items as yet unseen by this subscription in the delivery queue
      def self.check!(subscription)
        Subscriptions::Manager.poll(subscription, :check).each do |item|
          unless SeenId.where(:subscription_id => subscription.id, :item_id => item.id).first
            SeenId.create! :subscription_id => subscription.id, :item_id => item.id
            Subscriptions::Manager.schedule_delivery! subscription, item
          end  
        end
      end
      
      # non-destructive, searches for example results
      def self.search(subscription)
        Subscriptions::Manager.poll subscription, :search
      end
      
      def self.url_for(subscription, function)
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ bill.bill_id bill.bill_type bill.number bill.short_title bill.official_title bill.introduced_at bill.last_action_at bill.last_action version_code bill_version_id bill.session urls.pdf urls.xml issued_on }
        
        url = "#{endpoint}/search/bill_versions.json?apikey=#{api_key}"
        url << "&per_page=#{MAX_ITEMS}"
        url << "&query=#{query}"
        url << "&order=issued_on"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true&highlight_size=500"
        
        url
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response)
        return nil unless response['bill_versions']
        
        response['bill_versions'].map do |bv|
          item_for bv
        end
      end
      
      
      
      # internal
      
      def self.item_for(bill_version)
        # clean out the dot notation from the highlight fields,
        # since the data hash here may get stored in the database
        # use a double-underscore to guarantee never a conflict
        if highlight = bill_version['search']['highlight']
          highlight.keys.each do |key|
            if key["."]
              highlight[key.gsub('.', '__')] = highlight.delete key
            end
          end
        end
        
        # Long-winded justification for the above:
        
        # Having to do this shouldn't be viewed as a flaw on RTC's part; its job shouldn't be
        # to make sure its clients under no circumstances ever need to worry about putting the JSON output
        # directly into a Mongo database. 
        
        # The document data itself gets cleaned RTC-side of dot notation, but it doesn't make sense to change 
        # the structure of the highlight object as it comes back from ElasticSearch.
        # The highlight object should remain a flat set of keys that point to arrays of highlighted text, both to
        # preserve what we can from ES, and so that clients don't have to build in complicated parsing logic to understand
        # the highlighting of a document.
        
        # It also doesn't make sense to invent a new notation for separating subobjects on RTC's side just to 
        # avoid the edge case where a client wants to dump the entire thing into their own Mongo database. 
        # This is our particular client's problem.
        
        
        bill_version['issued_on'] = noon_utc_for bill_version['issued_on']
        
        Subscriptions::Item.new(
          :id => bill_version["bill_version_id"],
          :date => bill_version["issued_on"],
          :data => bill_version
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
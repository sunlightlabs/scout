require 'httparty'

module Subscriptions

  class Manager

    def self.search(subscription, options = {})      
      poll subscription, :search, options
    end
    
    def self.initialize!(subscription)

      # TODO: refactor so that these come in as the arguments
      interest = subscription.interest
      subscription_type = subscription.subscription_type

      # default strategy:
      # 1) does the initial poll
      # 2) stores every item ID as seen 

      # make initialization idempotent, remove any existing seen items first
      interest.seen_items.where(subscription_type: subscription_type).delete_all

      results = Subscriptions::Manager.poll(subscription, :initialize)

      # caller can decide whether it cares about the error hash
      return results unless results.is_a?(Array)

      results.each do |item|
        mark_as_seen! item
      end
      
      subscription.initialized = true
      subscription.last_checked_at = Time.now
      subscription.save!

      true
    end
    
    def self.check!(subscription)
      
      # TODO: refactor so that these come in as the arguments
      interest = subscription.interest
      subscription_type = subscription.subscription_type

      # if the subscription is orphaned, catch this, warn admin, and abort
      if interest.nil?
        subscription.seen_items.each {|i| i.destroy}
        subscription.destroy
        Admin.report Report.warning("Check", "Orphaned subscription, deleting, moving on", subscription: subscription.attributes.dup)
        return true
      end

      # any users' tag interests who are following a public tag that includes
      following_interests = interest.followers
      

      # catch any items which suddenly appear, dated in the past, 
      # that weren't caught during initialization or prior polls

      # accumulate backfilled items to report per-subscription.
      # buffer of 30 days, to allow for information to make its way through whatever 
      # pipelines it has to go through (could eventually configure this per-adapter)
      
      # Was 5 days, bumped it to 30 because of federal_bills. The LOC, CRS, and GPO all 
      # move in waves, apparently, of unpredictable frequency.

      # disabled in test mode (for now, this is obviously not ideal)

      backfills = []


      # 1) does a poll
      # 2) stores any items as yet unseen by this subscription in seen_ids
      # 3) stores any items as yet unseen by this subscription in the delivery queue
      results = Subscriptions::Manager.poll(subscription, :check)

      # caller can decide whether it cares about the error hash
      return results unless results.is_a?(Array)

      results.each do |item|

        unless SeenItem.where(:interest_id => interest.id, :item_id => item.item_id).first
          unless item.item_id
            Admin.report Report.warning("Check", "[#{interest.id}][#{subscription_type}][#{interest.in}] item with an empty ID")
            next
          end

          mark_as_seen! item

          if !test? and (item.date < 14.days.ago)
            # this is getting out of hand - 
            # don't deliver state bill backfills, but don't email me about them
            # temporary until Open States allows sorting by last_action dates
            if subscription_type != "state_bills"
              backfills << item.attributes
            end
          else
            # deliver one copy for the user whose interest found it
            Deliveries::Manager.schedule_delivery! item, interest, subscription_type

            # deliver a copy to any users following this one
            following_interests.each do |seen_through|
              Deliveries::Manager.schedule_delivery! item, interest, subscription_type, seen_through
            end
          end
        end

      end

      if backfills.any?
        Admin.report Report.warning("Check", "[#{subscription.subscription_type}][#{subscription.interest_in}] #{backfills.size} backfills not delivered, attached", :backfills => backfills)
      end
      
      subscription.last_checked_at = Time.now
      subscription.save!

      true
    end
    
    def self.mark_as_seen!(item)
      item.save!
    end

    def self.test?
      Sinatra::Application.test?
    end
    
    # function is one of [:search, :initialize, :check]
    # options hash can contain epheremal modifiers for search (right now just a 'page' parameter)
    def self.poll(subscription, function = :search, options = {})
      adapter = subscription.adapter
      url = adapter.url_for subscription, function, options
      
      puts "\n[#{subscription.subscription_type}][#{function}][#{subscription.interest_in}][#{subscription.id}] #{url}\n\n" if !test? and config[:debug][:output_urls]

      response = nil

      # this override is only used by the external feed parser, which is parsing some kind of XML feed
      if adapter.respond_to?(:url_to_response)
        begin
          response = adapter.url_to_response url
        rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ETIMEDOUT => ex
          return error_for "Timeout error polling feed", url, function, options, subscription, ex
        rescue AdapterParseException => ex
          return error_for "Error during initial processing of feed: #{ex.message}", url, function, options, subscription
        rescue Exception => ex
          # don't allow caller to accumulate unexpected errors, email right away
          report = Report.exception self, "Exception processing URL #{url}", ex, :subscription_type => subscription.subscription_type, :function => function, :interest_in => subscription.interest_in, :subscription_id => subscription.id
          puts report.to_s
          return error_for "Unknown error polling feed", url, function, options, subscription, ex
        end

      # every other adapter is parsing a remote JSON feed
      else
        begin
          response = HTTParty.get url
        rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ETIMEDOUT => ex
          return error_for "Timeout error", url, function, options, subscription, ex
        end
      end
      
      begin
        items = adapter.items_for response, function, options
      rescue AdapterParseException => ex
        return error_for ex.message, url, function, options, subscription
      end

      if items.is_a?(Array)
        items.map do |item| 
          item.assign_to_subscription subscription
          item.search_url = url
          item
        end
      else
        error_for "Unknown, items_for returned nil", url, function, options, subscription, ex
      end
    end

    def self.error_for(message, url, function, options, subscription, exception = nil)
      {
        message: message,
        url: url,
        function: function,
        options: options,
        subscription: subscription.attributes.dup,
        exception: (exception ? Report.exception_to_hash(exception) : nil)
      }
    end

    # given a type of adapter, and an item ID, fetch the item and return a seen item
    def self.find(adapter_type, item_id, options = {})
      adapter = Subscription.adapter_for adapter_type
      url = adapter.url_for_detail item_id, options
      
      puts "\n[#{adapter}][find][#{item_id}] #{url}\n\n" if !test? and config[:debug][:output_urls]
      
      begin
        response = HTTParty.get url
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ETIMEDOUT => ex
        Admin.report Report.warning("Find", "[#{adapter_type}][find][#{item_id}] find timeout, returned nil")
        return nil
      end
      
      item = adapter.item_detail_for response
      
      if item
        item.find_url = url
        item
      else
        nil
      end
    end

    # helper function to straighten dates into UTC times (necessary for serializing to BSON, sigh)
    def self.noon_utc_for(date)
      return nil unless date
      date.to_time.midnight + 12.hours
    end
    
  end

  # used by adapters to signal an error in parsing
  class AdapterParseException < Exception; end
  
end
require 'oj'

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
      # support rake task command line dry run flag
      dry_run = ENV["dry_run"] || false

      # TODO: refactor so that these come in as the arguments
      interest = subscription.interest
      subscription_type = subscription.subscription_type

      # if the subscription is orphaned, catch this, warn admin, and abort
      if interest.nil? and !dry_run
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
      if ENV['only_since']
        backfill_date = Time.zone.parse ENV['only_since']
      else
        backfill_date = 30.days.ago
      end


      # 1) does a poll
      # 2) stores any items as yet unseen by this subscription in seen_ids
      # 3) stores any items as yet unseen by this subscription in the delivery queue
      results = Subscriptions::Manager.poll(subscription, :check)

      # caller can decide whether it cares about the error hash
      return results unless results.is_a?(Array)

      results.each do |item|

        unless SeenItem.where(interest_id: interest.id, item_id: item.item_id).first
          unless item.item_id
            Admin.report Report.warning("Check", "[#{interest.id}][#{subscription_type}][#{interest.in}] item with an empty ID")
            next
          end

          mark_as_seen! item unless dry_run

          if !test? and (item.date < backfill_date)
            # this is getting out of hand - 
            # don't deliver state bill backfills, but don't email me about them
            # temporary until Open States allows sorting by last_action dates
            # if subscription_type != "state_bills"
              backfills << item.attributes
            # end
          else
            unless dry_run
              # deliver one copy for the user whose interest found it
              Deliveries::Manager.schedule_delivery! item, interest, subscription_type

              # deliver a copy to any users following this one
              following_interests.each do |seen_through|
                Deliveries::Manager.schedule_delivery! item, interest, subscription_type, seen_through
              end
            end
          end
        end

      end

      if backfills.any?
        Admin.report Report.warning("Check", "[#{subscription.subscription_type}][#{subscription.interest_in}] #{backfills.size} backfills not delivered, attached", :backfills => backfills)
      end
      
      unless dry_run
        subscription.last_checked_at = Time.now
        subscription.save!
      end

      true
    end
    
    def self.mark_as_seen!(item)
      item.save!
    end

    def self.test?
      Sinatra::Application.test?
    end

    def self.development?
      Sinatra::Application.development?
    end
    
    # function is one of [:search, :initialize, :check]
    # options hash can contain epheremal modifiers for search (right now just a 'page' parameter)
    def self.poll(subscription, function = :search, options = {})
      adapter = subscription.adapter
      url = adapter.url_for subscription, function, options
      
      puts "\n[#{subscription.subscription_type}][#{function}][#{subscription.interest_in}][#{subscription.id}] #{url}\n\n" if !test? and config[:debug][:output_urls]

      # this override is only used by the external feed parser, which is parsing some kind of XML feed
      if adapter.respond_to?(:url_to_response)
        begin
          response = adapter.url_to_response url
          items = adapter.items_for response, function, options
        rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
          Curl::Err::RecvError, Curl::Err::HostResolutionError, 
          Curl::Err::GotNothingError,
          Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
          return error_for "Network or timeout error while polling feed", url, function, options, subscription, ex
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
        items = begin
          # searches use a caching layer
          if (function == :search) and (body = cache_for(url, subscription.subscription_type))
            # should be guaranteed to work
            response = ::Oj.load body, mode: :compat
          else
            body = download url
            response = ::Oj.load body, mode: :compat

            # wait for JSON parse, so as not to cache errors
            if function == :search and !config[:no_cache]
              cache! url, subscription, body
            end
          end

          adapter.items_for response, function, options
        rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
          Curl::Err::RecvError, Curl::Err::HostResolutionError, 
          Curl::Err::GotNothingError,
          Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
          return error_for "Network or timeout error", url, function, options, subscription, ex
        rescue SyntaxError => ex
          message = if body =~ /504 Gateway Time-out/
            "Timeout (504)"
          else
            "JSON parser error, body was:\n\n#{body}"
          end
          return error_for message, url, function, options, subscription, ex
        rescue AdapterParseException => ex
          return error_for ex.message, url, function, options, subscription
        end
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
      
      puts "\n[#{adapter_type}][find][#{item_id}] #{url}\n\n" if !test? and config[:debug][:output_urls]
      
      response = begin
        body = download(url)
        ::Oj.load body, mode: :compat
      rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
          Curl::Err::RecvError, Curl::Err::HostResolutionError, 
          Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
        Admin.report Report.warning("find:#{adapter_type}", "[#{adapter_type}][find][#{item_id}] find timeout, returned nil")
        return nil
      rescue SyntaxError => ex
        Admin.report Report.exception("find:#{adapter_type}", "[#{adapter_type}][find][#{item_id}] JSON parse error, returned nil, body was:\n\n#{body}", ex)
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

    def self.cache_for(url, subscription_type)
      return if config[:no_cache]
      if result = Cache.where(url: url, subscription_type: subscription_type).first
        puts "USE CACHE: #{url}\n\n" if development?
        result.content
      end
    end

    def self.cache!(url, subscription, content)
      puts "\nCACHE: #{url}\n\n" if development?
      Cache.create!(
        url: url, 
        subscription_type: subscription.subscription_type, 
        interest_in: subscription.interest_in, 
        content: content
      )
    end

    # clear the cache for a subscription_type
    def self.uncache!(subscription_type)
      Cache.where(subscription_type: subscription_type).delete_all
    end

    # download content at the given URL
    def self.download(url, cache = {})
      curl = Curl::Easy.new url
      curl.perform
      curl.body_str
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
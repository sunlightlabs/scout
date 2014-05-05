require 'oj'

module Subscriptions

  class Manager
    # Sends an API request for all documents relevant to the subscription and
    # returns them as a list of items.
    #
    # @param [Subscription] subscription a subscription
    # @param [Hash] options
    # @option options [Integer] :page a page number
    # @option options [Integer] :per_page the number of items per page
    # @return [Array<SeenItem>,Hash] the items from the data source that match
    #   the subscription's query, or an error hash
    def self.search(subscription, options = {})
      poll subscription, :search, options
    end

    # @param [Subscription] subscription a subscription
    # @return [Hash,TrueClass] `true` or an error hash
    def self.initialize!(subscription)

      # TODO: refactor so that these come in as the arguments
      interest = subscription.interest
      subscription_type = subscription.subscription_type

      # if the subscription is orphaned, catch this, warn admin, and abort
      if interest.nil?
        subscription.seen_items.each {|i| i.destroy}
        subscription.destroy
        Admin.report Report.warning("Initialize", "Orphaned subscription, deleting, moving on", subscription: subscription.attributes.dup)
        return true
      end

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

    # @param [Subscription] subscription a subscription
    # @return [Hash,TrueClass] `true` or an error hash
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
      #
      # accumulate backfilled items to report per-subscription.
      # buffer of 30 days, to allow for information to make its way through whatever
      # pipelines it has to go through (could eventually configure this per-adapter)
      #
      # Was 5 days, bumped it to 30 because of federal_bills. The LOC, CRS, and GPO all
      # move in waves, apparently, of unpredictable frequency.
      #
      # disabled in test mode (for now, this is obviously not ideal)

      backfills = []
      if ENV['only_since']
        backfill_date = Time.zone.parse ENV['only_since']
      else
        backfill_date = 30.days.ago
      end

      # check for seeming courtlistener bugs
      courtlistener_warnings = []

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

          # if it fails the CourtListener double check, don't deliver
          if (subscription.subscription_type == "court_opinions") and !Subscriptions::Adapters::CourtOpinions.double_check(item)
            courtlistener_warnings << {
              item_data: item.data,
              subscription_query: subscription.query
            }

          # if it's a suddenly seen old item, don't deliver
          elsif !test? and (item.date < backfill_date)
            backfills << item.attributes

          # okay, schedule a delivery (unless this is a dry run)
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

      # store warnings for aggregated notice
      Event.backfills!(backfills, subscription.interest_in, subscription.subscription_type) if backfills.any?
      Event.courtlistener!(courtlistener_warnings, subscription.interest_in, subscription.subscription_type) if courtlistener_warnings.any?

      unless dry_run
        subscription.last_checked_at = Time.now
        subscription.save!
      end

      true
    end

    # @private
    def self.mark_as_seen!(item)
      item.save!
    end

    # @private
    def self.test?
      Sinatra::Application.test?
    end

    # @private
    def self.development?
      Sinatra::Application.development?
    end

    # Sends an API request for all documents relevant to the subscription and
    # returns them as a list of items.
    #
    # If performing a `:search` operation, it will check the cache before
    # sending the request and it will cache the response of the request.
    #
    # @param [Subscription] subscription a subscription
    # @param [Symbol] function one of:
    #   * `:check`: TODO
    #   * `:initialize`: TODO
    #   * `:search`: TODO
    # @param [Hash] options
    # @option options [String] :api_key an API key
    # @option options [Integer] :page a page number
    # @option options [Integer] :per_page the number of items per page
    # @option options [Boolean] :cache_only if truthy and if the cache contains
    #   no cached response of a request to the data source, then no requests are
    #   sent to the data source and `nil` is returned
    def self.poll(subscription, function = :search, options = {})
      adapter = subscription.adapter
      url = adapter.url_for subscription, function, options

      puts "\n[#{subscription.subscription_type}][#{function}][#{subscription.interest_in}][#{subscription.id}] #{url}\n\n" if !test? and Environment.config['debug']['output_urls']

      # Feed parser
      if adapter.respond_to?(:url_to_response)
        begin
          response = adapter.url_to_response url
          items = adapter.items_for response, function, options
        rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError,
          Curl::Err::RecvError, Curl::Err::HostResolutionError,
          Curl::Err::GotNothingError,
          Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
          return error_for "Network or timeout error while polling feed", url, function, options, subscription, ex
        rescue AdapterParseException, BadFetchException => ex
          return error_for "Error during initial processing of feed: #{ex.message}", url, function, options, subscription
        rescue Exception => ex
          # don't allow caller to accumulate unexpected errors, email right away
          report = Report.exception self, "Exception processing URL #{url}", ex, subscription_type: subscription.subscription_type, function: function, interest_in: subscription.interest_in, subscription_id: subscription.id
          puts report.to_s
          Admin.report report
          return error_for "Unknown error polling feed", url, function, options, subscription, ex
        end

      # Every other adapter is parsing a remote JSON feed
      else
        items = begin
          # searches use a caching layer
          if (function == :search) and (body = cache_for(url, :search, subscription.subscription_type))
            # should be guaranteed to work
            response = ::Oj.load body, mode: :compat

          # if the requestor does not want to hit the network, stop here
          elsif options[:cache_only]
            puts "NO CACHE, returning nothing" if !test?
            return nil

          else
            body = download url, adapter
            response = ::Oj.load body, mode: :compat

            # wait for JSON parse, so as not to cache errors
            if (function == :search) and !Environment.config['no_cache']
              cache! url, :search, subscription.subscription_type, body
            end
          end

          adapter.items_for response, function, options
        rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError,
          Curl::Err::RecvError, Curl::Err::HostResolutionError,
          Curl::Err::GotNothingError,
          Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
          return error_for "Network or timeout error", url, function, options, subscription, ex
        rescue Oj::ParseError, SyntaxError => ex
          message = if body =~ /504 Gateway Time-out/
            "Timeout (504)"
          else
            "JSON parser error, body was:\n\n#{body}"
          end
          return error_for message, url, function, options, subscription, ex
        rescue AdapterParseException, BadFetchException => ex
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

    # @private
    def self.error_for(message, url, function, options, subscription, exception = nil)
      {
        message: message,
        url: url,
        function: function,
        options: options,
        subscription: subscription ? subscription.attributes.dup : nil,
        exception: (exception ? Report.exception_to_hash(exception) : nil)
      }
    end

    # Sends an API request for a single document and returns it as an item.
    #
    # @param [String] adapter_type a subscription adapter's lowercase
    #   underscored name
    # @param [String] item_id a document's identifier in the data source
    # @param [Hash] options
    # @option options [String] :api_key an API key
    # @option options [Integer] :page a page number
    # @option options [Integer] :per_page the number of items per page
    # @option options [Boolean] :cache_only if truthy and if the cache contains
    #   no cached response of a request to the data source, then no requests are
    #   sent to the data source and `nil` is returned
    # @return [SeenItem,nil] the item, or nil
    def self.find(adapter_type, item_id, options = {})
      adapter = Subscription.adapter_for adapter_type
      item_type = search_adapters[adapter_type]

      url = adapter.url_for_detail item_id, options

      puts "\n[#{adapter_type}][find][#{item_id}] #{url}\n\n" if !test? and Environment.config['debug']['output_urls']

      # top-layer cache - if we've synced the item already, use it
      if item = item_cache_for(item_type, item_id)
        # pass
      else
        begin
          if body = cache_for(url, :find, adapter_type)
            response = ::Oj.load body, mode: :compat
          elsif options[:cache_only]
            return nil
          else
            body = download url, adapter
            response = ::Oj.load body, mode: :compat

            # wait for JSON parse, so as not to cache errors
            if !Environment.config['no_cache']
              cache! url, :find, adapter_type, body
            end
          end
        rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError,
            Curl::Err::RecvError, Curl::Err::HostResolutionError,
            Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
          Admin.report Report.warning("find:#{adapter_type}", "[#{adapter_type}][find][#{item_id}] find timeout, returned nil")
          return nil
        rescue Oj::ParseError, SyntaxError => ex
          Admin.report Report.exception("find:#{adapter_type}", "[#{adapter_type}][find][#{item_id}] JSON parse error, returned nil, body was:\n\n#{body}", ex)
          return nil
        end

        item = adapter.item_detail_for response
      end

      if item
        item.item_type = item_type
        item.find_url = url

        if adapter.respond_to?(:document_url) and (url = adapter.document_url item)
          # a url_type of 'document' means their cache will not get flushed --
          # which is what we want. keep documents forever.

          item.data['document'] = fetch url, :document, options
        end

        item
      else
        nil
      end
    end

    # get the content at an arbitrary location, using the same cache logic as the poll and find operations
    # (include adapter_type and item_id to better track what's happening)
    # @param [String] url
    # @param [Symbol] url_type always `:document`
    # @param [Hash] options
    # @option options [Boolean] :cache_only
    # @return [String] the response body
    # @private
    def self.fetch(url, url_type, options = {})
      puts "\n[fetch][#{url_type}] #{url}\n\n" if !test? and Environment.config['debug']['output_urls']

      body = nil
      begin
        if body = cache_for(url, :fetch, url_type)
          # nothing
        elsif options[:cache_only]
          return nil
        else
          body = download url
          if !Environment.config['no_cache']
            cache! url, :fetch, url_type, body
          end
        end
      rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError,
          Curl::Err::RecvError, Curl::Err::HostResolutionError,
          Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
        Admin.report Report.warning("fetch:#{url_type}", "[find][#{url_type}] find timeout, returned nil")
        return nil
      rescue BadFetchException => ex
        Admin.report Report.warning("fetch:#{url_type}", "[find][#{url_type}] #{ex.message}", url: url)
        return nil
      rescue Oj::ParseError, SyntaxError => ex
        Admin.report Report.exception("fetch:#{url_type}", "[find][#{url_type}] JSON parse error, returned nil, body was:\n\n#{body}", ex)
        return nil
      end

      body
    end

    # just get items and feed them into the parser -
    # no caching, no feed parsing, no related subscription
    # @param [String] subscription_type a subscription adapter's lowercase
    #   underscored name
    # @param [Hash] options
    # @option options [String] :since e.g. "all", "2010", "current"
    # @option options [Integer] :page a page number
    # @option options [Integer] :start a timestamp
    # @return [Array<SeenItem>,Hash] items from the data source or an error hash
    def self.sync(subscription_type, options = {})
      adapter = Subscription.adapter_for subscription_type
      url = adapter.url_for_sync options

      puts "\n[#{subscription_type}][sync][#{options[:page]}] #{url}\n\n" if !test? and Environment.config['debug']['output_urls']

      items = begin
        body = download url, adapter
        response = ::Oj.load body, mode: :compat
        adapter.items_for response, :sync, options
      rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError,
        Curl::Err::RecvError, Curl::Err::HostResolutionError,
        Curl::Err::GotNothingError,
        Timeout::Error, Errno::ECONNREFUSED, EOFError, Errno::ETIMEDOUT => ex
        return error_for "Network or timeout error", url, :sync, options, nil, ex
      rescue Oj::ParseError, SyntaxError => ex
        message = if body =~ /504 Gateway Time-out/
          "Timeout (504)"
        else
          "JSON parser error, body was:\n\n#{body}"
        end
        return error_for message, url, :sync, options, nil, ex
      rescue AdapterParseException, BadFetchException => ex
        return error_for ex.message, url, :sync, options, nil
      end

      items.map do |item|
        item.item_type = search_adapters[subscription_type]

        if adapter.respond_to?(:document_url) and (url = adapter.document_url item)
          # a url_type of 'document' means their cache will not get flushed --
          # which is what we want. keep documents forever.

          item.data['document'] = fetch url, :document, options
        end

        item
      end
    end

    # @private
    def self.item_cache_for(item_type, item_id)
      return nil if Environment.config['no_cache']

      if item = Item.where(item_type: item_type, item_id: item_id).first
        puts "ITEM CACHE: [#{item_type}][#{item_id}]\n\n" if development?
        Item.to_seen! item
      else
        nil
      end
    end

    # @private
    def self.cache_for(url, function, subscription_type)
      return nil if Environment.config['no_cache']

      if result = Cache.where(url: url, function: function, subscription_type: subscription_type).first
        puts "USE CACHE: [#{function}] #{url}\n\n" if development?
        result.content
      end
    end

    # @private
    def self.cache!(url, function, subscription_type, content)
      puts "\nCACHE: [#{function}] #{url}\n\n" if development?
      Cache.create!(
        url: url,
        subscription_type: subscription_type,
        function: function,
        content: content
      )
    end

    # clear the cache for a subscription_type (everything related to one adapter)
    def self.uncache!(subscription_type)
      Cache.where(subscription_type: subscription_type).delete_all
    end

    # download content at the given URL
    def self.download(url, adapter = nil)
      curl = Curl::Easy.new url

      curl.follow_location = true

      curl.headers["User-Agent"] = "Scout (scout.sunlightfoundation.com) / curl"

      # provide adapter an optional chance to modify Curl request
      if adapter and adapter.respond_to?(:http)
        curl = adapter.http curl
      end

      curl.perform

      ok = curl.status.start_with? "2"
      redirected = (curl.redirect_count >= 1) and curl.status.start_with?("3")

      if redirected
        puts "\tredirecting to: #{curl.redirect_url}"
      end

      if ok or redirected
        curl.body_str
      else
        message = "Bad status code: #{curl.status} at URL: #{url}"
        raise BadFetchException.new message
      end
    end
  end

  # used by adapters to signal an error in parsing
  class AdapterParseException < Exception; end
  class BadFetchException < Exception; end

end
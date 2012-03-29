require 'httparty'
require 'subscriptions/helpers'

module Subscriptions

  class Manager

    def self.search(subscription, options = {})
      poll subscription, :search, options
    end
    
    def self.initialize!(subscription)

      # allow overrides by individual adapters
      if subscription.adapter.respond_to?(:initialize!)
        subscription.adapter.initialize! subscription
      
      else
        # default strategy:
        # 1) does the initial poll
        # 2) stores every item ID as seen 

        # make initialization idempotent, remove any existing seen items first
        subscription.seen_items.delete_all

        Subscriptions::Manager.poll(subscription, :initialize).each do |item|
          mark_as_seen! subscription, item
        end
      end
      
      subscription.initialized = true
      subscription.last_checked_at = Time.now
      subscription.save!
    end
    
    def self.check!(subscription)
      
      # catch any items which suddenly appear, dated in the past, 
      # that weren't caught during initialization or prior polls
      backfills = []

      # allow overrides by individual adapters
      if subscription.adapter.respond_to?(:check!)
        subscription.adapter.check! subscription

      else
        # default strategy:
        # 1) does a poll
        # 2) stores any items as yet unseen by this subscription in seen_ids
        # 3) stores any items as yet unseen by this subscription in the delivery queue
        if results = Subscriptions::Manager.poll(subscription, :check)
          results.each do |item|

            unless SeenItem.where(:subscription_id => subscription.id, :item_id => item.item_id).first
              unless item.item_id
                Admin.report Report.warning("Check", "[#{subscription.subscription_type}][#{subscription.interest_in}] item with an empty ID")
                next
              end

              mark_as_seen! subscription, item

              # accumulate backfilled items to report per-subscription.
              # buffer of 8 days, to allow for information to make its way through whatever 
              # pipelines it has to go through (could eventually configure this per-adapter)
              
              # Was 5 days, bumped it to 30 because of federal_bills. The LOC, CRS, and GPO all 
              # move in waves, apparently, of unpredictable frequency.
              if item.date < 30.days.ago
                backfills << item.attributes
                next
              end

              Deliveries::Manager.schedule_delivery! item, subscription
            end
          end
        end
      end

      if backfills.any?
        Admin.report Report.warning("Check", "[#{subscription.subscription_type}][#{subscription.interest_in}] #{backfills.size} backfills detected, not delivered, attached", :backfills => backfills)
      end
      
      subscription.last_checked_at = Time.now
      subscription.save!
    end
    
    def self.mark_as_seen!(subscription, item)
      item.save!
    end
    
    # function is one of [:search, :initialize, :check]
    # options hash can contain epheremal modifiers for search (right now just a 'page' parameter)
    def self.poll(subscription, function = :search, options = {})
      adapter = subscription.adapter
      url = adapter.url_for subscription, function, options
      
      puts "\n[#{subscription.subscription_type}][#{function}][#{subscription.interest_in}][#{subscription.id}] #{url}\n\n" if config[:debug][:output_urls]
      
      begin
        response = HTTParty.get url
      rescue Timeout::Error, Errno::ETIMEDOUT => ex
        Admin.report Report.warning("Poll", "[#{subscription.subscription_type}][#{function}][#{subscription.interest_in}] poll timeout, returned an empty list")
        return [] # should be return nil, when we refactor this to properly accomodate failures in initialization, checking, and searching
      end
      
      items = adapter.items_for response, function, options
      
      if items
        items.map do |item| 

          item.attributes = {
            # insert a reference to the subscription that generated result
            :subscription => subscription,
            :subscription_type => subscription.subscription_type,
            :subscription_interest_in => subscription.interest_in,
            :interest_id => subscription.interest_id,

            # insert a reference to the URL this result was found in  
            :search_url => url
          }

          item
        end
      else
        nil
      end
    end

    # given a type of adapter, and an item ID, fetch the item and return a seen item
    def self.find(adapter_type, item_id, data = {})
      adapter = Subscription.adapter_for adapter_type
      url = adapter.url_for_detail item_id, data
      
      puts "\n[#{adapter}][find][#{item_id}] #{url}\n\n" if config[:debug][:output_urls]
      
      begin
        response = HTTParty.get url
      rescue Timeout::Error, Errno::ETIMEDOUT => ex
        Admin.report Report.warning("Find", "[#{adapter_type}][find][#{item_id}] find timeout, returned nil")
        return nil
      end
      
      item = adapter.item_detail_for response
      item[:find_url] = url
      item
    end
    
  end
  
end
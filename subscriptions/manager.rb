require 'httparty'
require 'subscriptions/helpers'

module Subscriptions

  class Manager
    
    def self.initialize!(subscription)

      # allow overrides by individual adapters
      if subscription.adapter.respond_to?(:initialize!)
        subscription.adapter.initialize! subscription
      
      else
        # default strategy:
        # 1) does the initial poll
        # 2) stores every item ID as seen 

        Subscriptions::Manager.poll(subscription, :initialize).each do |item|
          # don't check if the seen ID already exists, for 
          # anticipated performance reasons (yes, premature optimization)
          SeenId.create! :subscription_id => subscription.id, :item_id => item.id
        end
      end
      
      subscription.initialized = true
      subscription.last_checked_at = Time.now
      subscription.save!
    end
    
    def self.check!(subscription)
      
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

            unless SeenId.where(:subscription_id => subscription.id, :item_id => item.id).first
              unless item.id
                Email.report Report.warning("Check", "[#{subscription.subscription_type}][#{subscription.keyword}] item with an empty ID")
                next
              end

              SeenId.create! :subscription_id => subscription.id, :item_id => item.id

              Subscriptions::Manager.schedule_delivery! subscription, item
            end
          end
        end
      end
      
      subscription.last_checked_at = Time.now
      subscription.save!
    end
    
    def self.schedule_delivery!(subscription, item)
      puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.keyword}](#{item.id}) Scheduling delivery"
      
      Delivery.create!(
        :user_id => subscription.user.id,
        :user_email => subscription.user.email,
        
        :subscription_id => subscription.id,
        :subscription_type => subscription.subscription_type,
        :subscription_keyword => subscription.keyword,
        
        :item_id => item.id,
        :item_date => item.date,
        :item_data => item.data
      )
    end
    
    # function is one of [:search, :initialize, :check]
    def self.poll(subscription, function = :search)
      adapter = subscription.adapter
      url = adapter.url_for subscription, function
      
      puts "\n[#{adapter}][#{function}][#{subscription.id}] #{url}\n\n" if config[:debug][:output_urls]
      
      begin
        response = HTTParty.get url
      rescue Timeout::Error, Errno::ETIMEDOUT => ex
        Email.report Report.warning("Poll", "[#{subscription.subscription_type}][#{function}][#{subscription.keyword}] poll timeout, returned an empty list")
        return [] # should be return nil, when we refactor this to properly accomodate failures in initialization, checking, and searching
      end
      
      # insert the subscription onto each result
      results = adapter.items_for(response, function)
      
      if results
        results.map do |result| 
          result.subscription = subscription
          result
        end
      else
        nil
      end
    end
    
  end
  
  
  # utility class returned by adapters, then used to render displays and create various items in the database
  class Result
    
    # done so that when a template is rendered with this item as the context, 
    # it has all the subscription display helpers available to it
    include Subscriptions::Helpers
    include GeneralHelpers
    
    attr_accessor :id, :date, :data, :subscription
    
    def initialize(options)
      self.id = options[:id]
      self.date = options[:date]
      self.data = options[:data]
      self.subscription = options[:subscription]
    end
    
  end
  
end
require 'httparty'
require 'subscriptions/helpers'

module Subscriptions

  # utility functions each subscription adapter will need
  class Manager
    
    def self.initialize!(subscription)
      subscription.adapter.initialize! subscription
      
      subscription.initialized = true
      subscription.last_checked_at = Time.now
      subscription.save!
    end
    
    def self.check!(subscription)
      subscription.adapter.check! subscription
      
      subscription.last_checked_at = Time.now
      subscription.save!
    end
    
    def self.schedule_delivery!(subscription, item)
      Delivery.create!(
        # user ID and inline email
        :user_id => subscription.user.id,
        :user_email => subscription.user.email,
        
        # original subscription and inline type
        :subscription_id => subscription.id,
        :subscription_type => subscription.subscription_type,
        :subscription_keyword => subscription.keyword,
        
        :item => {
          :id => item.id,
          :data => item.data
        }
      )
    end
    
    # function is one of [:search, :initialize, :check]
    def self.poll(subscription, function = :search)
      adapter = subscription.adapter
      url = adapter.url_for subscription, function
      
      puts "\n[#{adapter}][#{function}][#{subscription.id}] #{url}\n\n" if config[:debug][:output_urls]
      
      response = HTTParty.get url
      adapter.items_for response
    end
    
    
  end
  
  
  # utility class returned by adapters, then used to create various items in the database
  class Item
    include Subscriptions::Helpers
    
    attr_accessor :id, :date, :data
    
    def initialize(options)
      self.id = options[:id]
      self.date = options[:date]
      self.data = options[:data]
    end
    
  end
  
end
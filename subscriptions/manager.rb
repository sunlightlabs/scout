require 'httparty'
require 'subscriptions/helpers'

module Subscriptions

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
      puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.keyword}](#{item.id}) Scheduling delivery"
      
      Delivery.create!(
        :user_id => subscription.user.id,
        :user_email => subscription.user.email,
        
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
      
      # insert the subscription onto each result
      adapter.items_for(response).map do |result| 
        result.subscription = subscription
        result
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
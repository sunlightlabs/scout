require 'httparty'

module Subscriptions

  class Manager
    
    # takes a new (uninitialized) subscription and:
    # 1) does the initial poll, 
    # 2) stores everything as seen in the appropriate tables
    # 3) records the latest item date
    # 4) marks the subscription as initialized
    def self.initialize(subscription)
      
    end
    
    # takes an initialized subscription and:
    # 1) does a poll
    # 2) checks for new items
    # 3) stores unseen items as seen in the appropriate tables
    # 4) records the latest item date
    def self.check(subscription)
      
    end
    
    
    # internal methods
    
    # returns an array where each item is a hash containing the id, title, and post date of each item found
    def self.poll(subscription)
      adapter = adapter_for subscription
      url = adapter.url_for subscription
      
      response = HTTParty.get url
      
      adapter.items_for response
    end
    
    # adapter class associated with a particular subscription
    def self.adapter_for(subscription)
      "Subscriptions::Adapters::#{subscription.subscription_type.camelize}".constantize rescue nil
    end
    
  end
  
  
  # utility class returned by adapters, then used to create various items in the database
  class Item
    
    attr_accessor :id, :title, :order_date, :data
    
    def initialize(options)
      self.id = options[:id]
      self.title = options[:title]
      self.order_date = options[:order_date]
      
      self.data = options[:data]
    end
    
  end
  
end
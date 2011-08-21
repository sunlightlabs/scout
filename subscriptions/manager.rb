require 'httparty'

module Subscriptions

  class Manager
    
    # ! denotes that it changes the subscription passed in (and by implication it needs to be a saved subscription)
    
    # takes a new (uninitialized) subscription and:
    # 1) does the initial poll, 
    # 2) stores everything as seen in the appropriate tables
    # 3) records the latest item date
    # 4) marks the subscription as initialized
    def self.initialize!(subscription)
      
    end
    
    # takes an initialized subscription and:
    # 1) does a poll
    # 2) checks for new items
    # 3) stores unseen items as seen in the appropriate tables
    # 4) records the latest item date
    def self.check!(subscription)
      
    end
    
    
    # internal methods, do not alter the subscription passed in
    
    # returns an array where each item is a hash containing the id, title, and post date of each item found
    def self.poll(subscription)
      adapter = subscription.adapter
      url = adapter.url_for subscription
      
      response = HTTParty.get url
      
      adapter.items_for response
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
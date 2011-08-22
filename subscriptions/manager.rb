require 'httparty'

module Subscriptions

  class Manager
    
    # ! denotes that it changes the database, possibly including the subscription passed in 
    # (and by implication the subscription passed in needs to be a saved subscription)
    
    
    # takes a new (uninitialized) subscription and:
    # 1) does the initial poll, 
    # 2) stores everything as seen in the appropriate tables
    # 3) marks the subscription as initialized
    def self.initialize!(subscription)
      items = poll subscription
      
      # store all items in the seen IDs table
      # store any unseen items in the seen items table
      items.each do |item|
        # all existing IDs are now considered "seen" by this subscription
        SeenId.create! :subscription_id => subscription.id, :item_id => item.id
        
        unless SeenItem.where(:subscription_type => subscription.subscription_type, :item_id => item.id).first
          SeenItem.create! :subscription_type => subscription.subscription_type, :item_id => item.id, :data => item.data
        end
      end
      
      # not delivering anything, this subscription was just made and anything there is presumed to have been "seen"
      
      # mark subscription as initialized
      subscription.initialized = true
      subscription.save!
    end
    
    # takes an initialized subscription and:
    # 1) does a poll
    # 2) stores any items as yet unseen by the system in seen items
    # 3) stores any items as yet unseen by this subscription in seen_ids
    # 4) stores any items as yet unseen by this subscription in the delivery queue
    def self.check!(subscription)
      items = poll subscription
      
      user = User.where(:_id => subscription.user_id).first
      
      deliveries = []
      
      items.each do |item|
        # find or create the item in the system library of items that have come through
        unless seen_item = SeenItem.where(:subscription_type => subscription.subscription_type, :item_id => item.id).first
          seen_item = SeenItem.create! :subscription_type => subscription.subscription_type, :item_id => item.id, :data => item.data
        end
        
        # if the item hasn't been seen, mark it and add it to the delivery queue
        unless SeenId.where(:subscription_id => subscription.id, :item_id => item.id).first
          SeenId.create! :subscription_id => subscription.id, :item_id => item.id
          deliveries << Delivery.create!(
            :subscription_id => subscription.id,
            :user_id => user.id,
            :seen_item_id => seen_item.id,
            :user_email => user.email,
            :subscription_type => subscription.subscription_type,
            :data => item.data
          )
        end
        
      end
      
      # return delivery items made
      deliveries
    end
    
    
    # internal methods, do not alter the subscription passed in
    
    # returns an array where each item is a hash containing the id, title, and post date of each item found
    def self.poll(subscription)
      adapter = subscription.adapter
      url = adapter.url_for subscription
      
      puts "[DEBUG] Polling #{url}"
      
      response = HTTParty.get url
      
      adapter.items_for response
    end
    
    
  end
  
  
  # utility class returned by adapters, then used to create various items in the database
  class Item
    
    attr_accessor :id, :data
    
    def initialize(options)
      self.id = options[:id]
      self.data = options[:data]
    end
    
  end
  
end
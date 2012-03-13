# should already be loaded as dependencies of sinatra
require 'erb'
require 'tilt'

module Deliveries
  module Manager

    def self.deliver!(user_options)
      receipts = []

      begin
        User.where(user_options).each do |user|
          if user.delivery['mechanism'] == 'email'
            receipts += Deliveries::Email.deliver_for_user! user
          else
            Admin.message "Unsure how to deliver to user #{user.email}, no known delivery mechanism"
          end
        end
      rescue Exception => ex
        Admin.report Report.exception("Delivery", "Problem during delivery.", ex)
        puts "Error during delivery, emailed report."
      end

      # Temporary, but for now I want to know when emails go out
      if receipts.any?
        msgs = receipts.map(&:to_s).join "\n\n"
        Admin.message "Sent #{receipts.size} notifications", msgs
      else
        puts "No notifications sent."
      end
    end

    def self.schedule_delivery!(subscription, item)
      puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.interest_in}](#{item.item_id}) Scheduling delivery"
      
      Delivery.create!(
        :user_id => subscription.user.id,
        :user_email => subscription.user.email,
        # todo - include user_phone
        # :user_phone => subscription.user.phone,
        
        :subscription_id => subscription.id,
        :subscription_type => subscription.subscription_type,
        :subscription_interest_in => subscription.interest_in,

        :interest_id => subscription.interest_id,
        
        :item_id => item.item_id,
        :item_date => item.date,
        :item_data => item.data,
        :item_search_url => item.search_url
      )
    end
  end

  # dummy proxy class to provide a context with helper modules included so that ERB can render properly
  class SeenItemProxy
    include GeneralHelpers
    include ::Subscriptions::Helpers

    attr_accessor :item

    def method_missing(m, *args, &block)
      item.send m, *args, &block
    end

    def initialize(item)
      self.item = item
    end
  end
end
# should already be loaded as dependencies of sinatra
require 'erb'
require 'tilt'

module Deliveries
  module Manager

    def self.deliver!(user_options)
      receipts = []

      User.where(user_options).each do |user|
        if user.delivery['mechanism'] == 'email'
          receipts += Deliveries::Email.deliver_for_user! user
        else
          Admin.message "Unsure how to deliver to user #{user.email}, no known delivery mechanism"
        end
      end
      
      # Let admin know when emails go out
      if receipts.any?
        Admin.message "Sent #{receipts.size} notifications", report_for(receipts)
      else
        puts "No notifications sent."
      end
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during delivery.", ex)
      puts "Error during delivery, emailed report."
    end

    def self.interest_name(interest)
      if interest.item?
        Subscription.adapter_for(interest_data[interest.interest_type][:adapter]).interest_name(interest)
      else
        interest.in
      end
    end

    def self.schedule_delivery!(item, subscription = nil)
      # Allow subscription to be passed in to prevent a database lookup, but not necessary
      subscription||= item.subscription
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
        
        # drop the item into the delivery wholesale
        :item => item.attributes.dup
      )
    end

    def self.report_for(receipts)
      report = ""
      
      receipts.group_by(&:user_email).each do |email, user_receipts|
        user = User.where(:email => email).first
        report << "#{user.to_admin} #{user_receipts.size} notifications"

        user_receipts.each do |receipt|
          receipt.deliveries.group_by {|d| d['interest_id']}.each do |interest_id, interest_deliveries|
            interest = Interest.find interest_id
            report << "\n\t#{interest_name interest} - #{interest_deliveries.size} things"
            report << "\n\t\t"
            report << interest_deliveries.group_by {|d| d['subscription_type']}.map do |subscription_type, subscription_deliveries|
              "#{subscription_type} (#{subscription_deliveries.size})"
            end.join(", ")
          end
          report << "\n\n"
        end
      end

      report
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
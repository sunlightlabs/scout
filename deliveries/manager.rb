
module Deliveries
  module Manager

    extend Helpers::Routing

    def self.deliver!(delivery_options)
      receipts = []

      dry_run = ENV["dry_run"] || false

      # all users with deliveries of the requested mechanism and email frequency
      user_ids = Delivery.where(delivery_options).distinct :user_id
      users = User.where(:_id => {"$in" => user_ids}).all

      users.each do |user|
        if delivery_options['mechanism'] == 'email'
          receipts += Deliveries::Email.deliver_for_user! user, delivery_options['email_frequency'], dry_run
        elsif delivery_options['mechanism'] == 'sms'
          receipts += Deliveries::SMS.deliver_for_user! user, dry_run
        else
          Admin.message "Unsure how to deliver to user #{user.email}, no known delivery mechanism for #{delivery_options['mechanism']}"
        end
      end
      
      # Let admin know when emails go out
      if receipts.any?
        Admin.message "Sent #{receipts.size} notifications", report_for(receipts, delivery_options)
      else
        puts "No notifications sent."
      end
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during delivery.", ex)
      puts "Error during delivery, emailed report."
    end

    def self.schedule_delivery!(item, 
      # Allow subscription to optionally be passed in to prevent a database lookup
      subscription = nil, 

      # Allow manual override of delivery options (useful for debugging)
      mechanism = nil, 
      email_frequency = nil
      )

      # subscription and user can be looked up using only the item if need be
      subscription ||= item.subscription
      interest = subscription.interest
      user = subscription.user

      # delivery options come from the interest, if none specified it inherits from the user
      mechanism ||= interest.mechanism
      email_frequency ||= interest.email_frequency

      if !["email", "sms"].include?(mechanism)
        puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.interest_in}](#{item.item_id}) Not scheduling delivery, user wants no notifications for this interest" unless Sinatra::Application.test?
      else
        puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.interest_in}](#{item.item_id}) Scheduling delivery" unless Sinatra::Application.test?

        Delivery.create!(
          :user_id => user.id,
          :user_email => user.email,
          :user_phone => user.phone,
          
          :subscription_id => subscription.id,
          :subscription_type => subscription.subscription_type,
          
          :interest_in => subscription.interest_in,
          :interest_id => subscription.interest_id,

          :mechanism => mechanism,
          :email_frequency => email_frequency,
          
          # drop the item into the delivery wholesale
          :item => item.attributes.dup
        )
      end
    end

    def self.report_for(receipts, delivery_options)
      report = ""

      delivery_type = "[#{delivery_options['mechanism']}]"
      if delivery_options['mechanism'] == 'email'
        delivery_type << "[#{delivery_options['email_frequency']}]"
      end
      
      receipts.group_by(&:user_email).each do |email, user_receipts|
        user = User.where(:email => email).first
        report << "[#{email}]#{delivery_type} #{user_receipts.size} notifications"

        user_receipts.each do |receipt|
          receipt.deliveries.group_by {|d| d['interest_id']}.each do |interest_id, interest_deliveries|
            interest = Interest.find interest_id
            report << "\n\t#{interest_name interest} - #{interest_deliveries.size} things"
            report << "\n\t\t"
            report << interest_deliveries.group_by {|d| d['subscription_type']}.map do |subscription_type, subscription_deliveries|
              "#{subscription_type} (#{subscription_deliveries.size})"
            end.join(", ")
          end
        end
        report << "\n\n"
      end

      report
    end

  end

  # dummy proxy class to provide a context with helper modules included so that ERB can render properly
  class SeenItemProxy
    include Helpers::General
    include Helpers::Routing
    include Helpers::Subscriptions

    attr_accessor :item

    def method_missing(m, *args, &block)
      item.send m, *args, &block
    end

    def initialize(item)
      self.item = item
    end
  end
end
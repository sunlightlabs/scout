
module Deliveries
  module Manager

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

    def self.interest_name(interest)
      if interest.item?
        Subscription.adapter_for(interest_data[interest.interest_type][:adapter]).interest_name(interest)
      else
        interest.in
      end
    end

    # used in linking to interests in SMS
    def self.interest_path(interest, preferred_type = nil)
      if interest.item?
        "/item/#{interest.interest_type}/#{interest.in}"
      elsif interest.search?
        # this sucks, and needs to change
        if preferred_type
          interest.subscriptions.first.scout_search_url(:subscription_type => preferred_type)
        elsif interest.subscriptions.count > 1 
          interest.subscriptions.first.scout_search_url(:subscription_type => "all")
        else
          interest.subscriptions.first.scout_search_url
        end
      end
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
        puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.interest_in}](#{item.item_id}) Not scheduling delivery, user wants no notifications for this interest"
      else
        puts "[#{subscription.user.email}][#{subscription.subscription_type}][#{subscription.interest_in}](#{item.item_id}) Scheduling delivery"

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
    include GeneralHelpers
    include Routing
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
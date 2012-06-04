
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
        next unless user.confirmed? # last-minute check, shouldn't be needed

        if delivery_options['mechanism'] == 'email'
          receipts += Deliveries::Email.deliver_for_user! user, delivery_options['email_frequency'], dry_run
        elsif delivery_options['mechanism'] == 'sms'
          receipts += Deliveries::SMS.deliver_for_user! user, dry_run
        else
          Admin.message "Unsure how to deliver to user #{user.email || user.phone}, no known delivery mechanism for #{delivery_options['mechanism']}"
        end
      end
      
      # Let admin know when emails go out
      if receipts.any?
        Admin.message "Sent #{receipts.size} notifications", report_for(receipts, delivery_options)
      else
        puts "No notifications sent." unless Sinatra::Application.test?
      end
    end


    # given the item to be delivered, the interest that found it with what subscription_type
    # and assuming the user's setup checks out (if sms, has phone, etc.)
    # then schedule the delivery
    def self.schedule_delivery!(
      item, interest, subscription_type,

      # interest that asked for the delivery (defaults to same as the finding interest)
      seen_through = nil,

      # Allow manual override of delivery options (useful for debugging)
      mechanism = nil, 
      email_frequency = nil
      )

      # asking interest defaults to the interest that found it
      seen_through ||= interest

      # the asking interest's user, who will get the delivery
      user = seen_through.user

      # delivery options come from the interest it was seen through,
      # if none is specified, the interest inherits the pref from the user
      mechanism ||= seen_through.mechanism
      email_frequency ||= seen_through.email_frequency

      header = "[#{user.email || user.phone}][#{interest.in}][#{subscription_type}](#{item.item_id})"
      header << "{through_tag}" if seen_through.tag?

      if !["email", "sms"].include?(mechanism)
        puts "#{header} Not scheduling delivery, user wants no notifications for this interest" unless Sinatra::Application.test?
      elsif !user.confirmed?
        puts "#{header} Not scheduling delivery, user is unconfirmed" unless Sinatra::Application.test?
      elsif (mechanism == "sms") and (user.phone.blank? or !user.phone_confirmed)
        puts "#{header} Not scheduling delivery, it is for SMS and user has no confirmed phone number" unless Sinatra::Application.test?
      else
        puts "#{header} Scheduling delivery" unless Sinatra::Application.test?

        # finally schedule the actual delivery
        Delivery.schedule! item, interest, subscription_type, seen_through, user, mechanism, email_frequency
      end
    end

    def self.report_for(receipts, delivery_options)
      report = ""

      delivery_type = "[#{delivery_options['mechanism']}]"
      if delivery_options['mechanism'] == 'email'
        delivery_type << "[#{delivery_options['email_frequency']}]"
      end
      
      receipts.group_by(&:user_id).each do |user_id, user_receipts|
        user = User.find user_id
        report << "[#{user.email || user.phone}]#{delivery_type} #{user_receipts.size} notifications"

        user_receipts.each do |receipt|
          receipt.deliveries.group_by {|d| [d['interest_id'], d['seen_through_id']]}.each do |interest_ids, interest_deliveries|
            interest_id, seen_through_id = interest_ids
            
            interest = Interest.find interest_id

            report << "\n\t#{interest_name interest} - #{interest_deliveries.size} things"
            
            if interest_id != seen_through_id 
              seen_through = Interest.find seen_through_id
              tag = seen_through.tag
              user = seen_through.tag_user
              report << "\n\tthrough: #{user.username || user.id} / #{tag.name}"
            end

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
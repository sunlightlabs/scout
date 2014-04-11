module Deliveries
  module Manager

    extend Helpers::Routing

    # to be called directly, not hooked into tasks
    def self.custom_email!(subject, header, interest_conditions)
      receipts = []

      dry_run = ENV["dry_run"] || false
      limit = ENV["limit"] || nil
      email = ENV["email"] || nil

      # all users with interests of the specified type
      interests = Interest.where interest_conditions
      user_ids = interests.distinct :user_id
      conditions = {_id: {"$in" => user_ids}}

      if email
        conditions[:email] = email
      end

      users = User.where(conditions).all

      if limit
        users = users[0..limit]
      end

      users.each do |user|
        next unless user.confirmed? # last-minute check, shouldn't be needed

        interests = user.interests.where(interest_conditions).all
        if interests.any?
          receipts += Deliveries::Email.deliver_custom!(
            user, interests, {
              'subject' => subject,
              'header' => header,
              'dry_run' => dry_run
            }
          )
        end
      end

      # Let admin know when emails go out
      if receipts.any?
        delivery_options = {"mechanism" => "email", "email_frequency" => "custom"}
        Admin.message "Sent #{receipts.size} notifications", report_for(receipts, delivery_options)
      else
        puts "No notifications sent." unless Sinatra::Application.test?
      end
    end


    def self.deliver!(delivery_options)
      receipts = []

      dry_run = ENV["dry_run"] || false

      # all users with deliveries of the requested mechanism and email frequency
      deliveries = Delivery.where delivery_options
      deliveries_count = deliveries.count
      user_ids = deliveries.distinct :user_id
      interest_ids = deliveries.distinct :interest_id

      users = User.where(_id: {"$in" => user_ids}).all

      # if there's a suspiciously high amount of deliveries,
      # leave the deliveries there and notify the admin
      if ENV['force'].blank?

        # suspicious: if the deliveries are returning, on average,
        # more than half of the max that they could be

        max_per_page = 40 # for now, anyway
        threshold = 0.5

        if deliveries_count > (interest_ids.size * max_per_page * threshold)
          flood_check "Too many deliveries", deliveries_count, delivery_options, user_count: user_ids.size, interest_count: interest_ids.size
          return
        end
      end

      users.each do |user|
        next unless user.confirmed? # last-minute check, shouldn't be needed

        if delivery_options['mechanism'] == 'email'
          receipts += Deliveries::Email.deliver_for_user! user, delivery_options['email_frequency'], {"dry_run" => dry_run}
        else
          Admin.message "Unsure how to deliver to user #{user.email}, no known delivery mechanism for #{delivery_options['mechanism']}"
        end
      end

      # Let admin know when emails go out
      if receipts.any?
        Admin.message "Sent #{receipts.size} notifications", report_for(receipts, delivery_options)
      else
        puts "No notifications sent." unless Sinatra::Application.test?
      end
    end

    def self.flood_check(message, size, delivery_options, options = {})
      Admin.report Report.warning("Flood Check",
        "High amount (#{size}) of deliveries, leaving in place and not delivering",
        {:delivery_count => size,
        :message => message,
        :subscription_types => Delivery.where(delivery_options).distinct(:subscription_type),
        :delivery_options => delivery_options}.merge(options)
        )
    end


    # given the item to be delivered, the interest that found it with what subscription_type
    # and assuming the user's setup checks out
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

      header = "[#{user.email}][#{interest.in}][#{subscription_type}](#{item.item_id})"
      header << "{through_tag}" if seen_through.tag?

      if !["email"].include?(mechanism)
        puts "#{header} Not scheduling delivery, user wants no notifications for this interest" unless Sinatra::Application.test?
      elsif !user.confirmed?
        puts "#{header} Not scheduling delivery, user is unconfirmed" unless Sinatra::Application.test?
      else
        puts "#{header} Scheduling delivery" unless Sinatra::Application.test?

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
        report << "[#{user.email}]#{delivery_type} #{user_receipts.size} notifications"

        user_receipts.each do |receipt|
          receipt.deliveries.group_by {|d| [d['interest_id'], d['seen_through_id']]}.each do |interest_ids, interest_deliveries|
            interest_id, seen_through_id = interest_ids

            # there's a chance the interest has been deleted by the time the report is generated,
            # like if someone gets an email and then immediately unsubscribes from it,
            # before the report is generated at the conclusion of sending all those emails.
            # (I did this once myself.)
            # If this happens, replace the interest_name with "[deleted - #{id}]" and move on.
            if interest = Interest.find(interest_id)
              name = interest_name interest
            else
              name = "[deleted - #{interest_id}]"
            end

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

  # dummy proxy class to provide a context with helper modules
  # included so that ERB can render with their assistance
  require "./deliveries/email"
  class SeenItemProxy
    include Helpers::General
    include Helpers::Routing
    include Helpers::Subscriptions
    extend Deliveries::Email::Rendering # this is so dumb

    attr_accessor :item

    def method_missing(m, *args, &block)
      item.send m, *args, &block
    end

    def initialize(item = nil)
      self.item = item
    end
  end
end
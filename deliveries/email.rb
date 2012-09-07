# should already be loaded as dependencies of sinatra
require 'erb'
require 'tilt'

module Deliveries
  module Email

    # give these methods at the class level, since all the methods in here are class methods
    extend Helpers::Routing

    def self.deliver_for_user!(user, frequency, dry_run = false)
      failures = []
      successes = []

      email = user.email

      matching_deliveries = user.deliveries.where(:mechanism => "email", :email_frequency => frequency).desc("item.date").all
      interest_deliveries = matching_deliveries.group_by &:interest

      # if sending whenever, then send one email per-interest
      if frequency == 'immediate'

        interest_deliveries.each do |interest, deliveries|          
          content = render_interest interest, deliveries
          content = render_final content

          subject = render_subject interest, deliveries

          if dry_run
            ::Email.sent_message("DRY RUN", "User", email, subject, content)
          else
            if email_user email, subject, content
              # delete first, save receipt after, in case an error in
              # saving the receipt leaves the delivery around to be re-delivered
              serialized = serialize_deliveries deliveries
              deliveries.each &:delete 
              successes << save_receipt!(frequency, user, serialized, subject, content)
            else
              failures << {:frequency => frequency, :email => email, :subject => subject, :content => content, :interest_id => interest.id.to_s}
            end
          end
        end
      
      elsif frequency == 'daily' # digest all deliveries into one single email
        
        if matching_deliveries.any? # not sure why this would be the case, but, just in case

          content = ""

          interest_deliveries.each do |interest, deliveries|
            content << render_interest(interest, deliveries)
          end
          
          content = render_final content
          subject = "Daily digest - #{matching_deliveries.size} new #{matching_deliveries.size > 1 ? "results" : "result"}"

          if dry_run
            ::Email.sent_message("DRY RUN", "User", email, subject, content)
          else
            if email_user(email, subject, content)
              # delete first, save receipt after, in case an error in
              # saving the receipt leaves the delivery around to be re-delivered
              serialized = serialize_deliveries matching_deliveries
              matching_deliveries.each &:delete
              successes << save_receipt!(frequency, user, serialized, subject, content)
            else
              failures << {:frequency => frequency, :email => email, :subject => subject, :content => content, :interest_id => interest.id.to_s}
            end
          end
        end
      end

      if failures.size > 0
        Admin.report Report.failure("Delivery", "Failed to deliver #{failures.size} emails to #{email}", :failures => failures)
      end

      if successes.any?
        Report.success("Delivery", "Delivered #{successes.size} emails to #{email}")
      end

      successes
    end

    def self.save_receipt!(frequency, user, deliveries, subject, content)
      Receipt.create!(
        :email_frequency => frequency,
        :mechanism => "email",

        :deliveries => deliveries,

        :user_id => user.id,
        :user_email => user.email,
        :user_notifications => user.notifications,

        :subject => subject,
        :content => content,
        :delivered_at => Time.now
      )
    end

    def self.serialize_deliveries(deliveries)
      deliveries.map {|delivery| delivery.attributes.dup}
    end

    def self.render_interest(interest, deliveries)
      grouped = deliveries.group_by &:subscription_type

      content = ""

      grouped.each do |subscription_type, group|
        description = "#{group.size} #{Subscription.adapter_for(subscription_type).short_name group.size, interest}"

        if interest.filters.any? 
          filters = interest.filters.map do |field, value|
            interest.filter_name field, value
          end.join(", ")
          description << " (#{filters})"
        end

        content << "- #{Deliveries::Manager.interest_name interest} - #{description}\n\n\n"

        group.each do |delivery|
          content << render_delivery(delivery, interest, subscription_type)
          content << "\n\n\n"
        end

        content << "\n"
      end

      content
    end

    # subject line for per-interest emails
    def self.render_subject(interest, deliveries)
      subject = "#{Deliveries::Manager.interest_name interest} - "

      grouped = deliveries.group_by(&:subscription_type)

      if grouped.keys.size > 3
        subject << "#{deliveries.size} new results" # deliveries.size is guaranteed to be > 1 if the grouped is > 3
      else
        subject << grouped.map do |subscription_type, subscription_deliveries|
          type = "#{subscription_deliveries.size} #{Subscription.adapter_for(subscription_type).short_name subscription_deliveries.size, interest}"
          
          if grouped.keys.size == 1 and interest.filters.any? 
            filters = interest.filters.map do |field, value|
              interest.filter_name field, value
            end.join(", ")
            type << " (#{filters})"
          end
          
          type
        end.join(", ")
      end

      subject
    end

    def self.render_final(content)
      content << "----------------\nManage your subscriptions on the web at #{config[:hostname]}/account/subscriptions."
      content << "\n\nThese notifications are powered by the nonpartisan Sunlight Foundation (sunlightfoundation.com), a nonprofit that uses cutting-edge technology and ideas to make government transparent and accountable."
      content << "\n\nReply to this email to send feedback, bug reports, or effusive praise our way."
      content << "\n\nTo unsubscribe from all emails: #{config[:hostname]}/account/unsubscribe"
      content
    end

    # render a Delivery into its email content
    def self.render_delivery(delivery, interest, subscription_type)
      item = Deliveries::SeenItemProxy.new(SeenItem.new(delivery.item))
      template = Tilt::ERBTemplate.new "app/views/subscriptions/#{subscription_type}/_email.erb"
      rendered = template.render item, :item => item, :interest => interest, :trim => false
      rendered.force_encoding "utf-8"
      rendered << "\n\n#{item_url item}"
    end

    # the actual mechanics of sending the email
    def self.email_user(email, subject, content)
      ::Email.deliver! "User", email, subject, content
    end

  end
end

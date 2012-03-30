module Deliveries
  module Email

    def self.deliver_for_user!(user, frequency)
      failures = 0
      successes = []

      email = user.email

      matching_deliveries = user.deliveries.where(:mechanism => "email", :email_frequency => frequency).all
      interest_deliveries = matching_deliveries.group_by &:interest

      # if sending whenever, then send one email per-interest
      if frequency == 'immediate'

        interest_deliveries.each do |interest, deliveries|          
          content = render_interest interest, deliveries
          content = render_final content

          subject = render_subject interest, deliveries

          if email_user email, subject, content
            successes << save_receipt!(frequency, user, deliveries, subject, content)
            deliveries.each &:delete
          else
            failures += 1
          end
        end
      
      elsif frequency == 'daily' # digest all deliveries into one single email
        
        if matching_deliveries.any? # not sure why this would be the case, but, just in case

          content = ""

          interest_deliveries.each do |interest, deliveries|
            content << render_interest(interest, deliveries)
          end
          
          content = render_final content
          subject = "Daily digest - #{matching_deliveries.size} new things"

          if email_user email, subject, content
            successes << save_receipt!(frequency, user, matching_deliveries, subject, content)
            matching_deliveries.each &:delete
          else
            failures += 1
          end
        end
      end

      if failures > 0
        Admin.report Report.failure("Delivery", "Failed to deliver #{failures} emails to #{email}")
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

        :deliveries => deliveries.map {|delivery| delivery.attributes.dup},

        :user_email => user.email,
        :user_delivery => user.delivery,

        :subject => subject,
        :content => content,
        :delivered_at => Time.now
      )
    end

    def self.render_interest(interest, deliveries)
      grouped = deliveries.group_by &:subscription

      content = ""

      grouped.each do |subscription, group|
        description = "#{group.size} #{subscription.adapter.short_name group.size, subscription, interest}"

        content << "- #{Deliveries::Manager.interest_name interest} - #{description}\n\n\n"

        group.each do |delivery|
          content << render_delivery(subscription, interest, delivery)
          content << "\n\n\n"
        end

        content << "\n"
      end

      content
    end

    # subject line for per-interest emails
    def self.render_subject(interest, deliveries)
      subject = "#{Deliveries::Manager.interest_name interest} - "

      grouped = deliveries.group_by(&:subscription)

      if grouped.keys.size > 3
        subject << "#{deliveries.size} new things"
      else
        subject << grouped.map do |subscription, subscription_deliveries|
          "#{subscription_deliveries.size} #{subscription.adapter.short_name subscription_deliveries.size, subscription, interest}"
        end.join(", ")
      end

      subject
    end

    def self.render_final(content)
      content << "----------------\nManage your subscriptions on the web at http://#{config[:hostname]}."
      content << "\n\nThese notifications are powered by the Sunlight Foundation (sunlightfoundation.com), a non-profit, non-partisan institution that uses cutting-edge technology and ideas to make government transparent and accountable."
      content << "\n\nReply to this email to send feedback, bug reports, or effusive praise our way."
      content
    end

    # render a Delivery into its email content
    def self.render_delivery(subscription, interest, delivery)
      item = Deliveries::SeenItemProxy.new(SeenItem.new(delivery.item))
      template = Tilt::ERBTemplate.new "views/subscriptions/#{subscription.subscription_type}/_email.erb"
      template.render item, :item => item, :subscription => subscription, :interest => interest, :trim => false
    end

    # the actual mechanics of sending the email
    def self.email_user(email, subject, content)
      ::Email.deliver! "User", email, subject, content
    end

  end
end
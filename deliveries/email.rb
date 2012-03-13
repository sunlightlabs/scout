module Deliveries
  module Email

    def self.deliver_for_user!(user)
      failures = 0
      successes = []

      email = user.email
      frequency = user.delivery['email_frequency']
      interests = user.interests.all

      # if sending whenever, then send one email per-interest
      #if frequency == 'immediate'

        interests.each do |interest|
          deliveries = Delivery.where(:interest_id => interest.id).all.to_a
          next unless deliveries.any?
          
          content = render_interest interest, deliveries
          content = render_final content
          subject = "#{Deliveries::Manager.interest_name interest} - #{deliveries.size} new things"

          if email_user email, subject, content
            deliveries.each &:delete
            successes << save_receipt!(frequency, user, deliveries, subject, content)
          else
            failures += 1
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
        :frequency => frequency,

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
        # if interest.search?
        #   description = search_data[subscription.subscription_type][:description]
        # else
        #   description = interest_data[interest.interest_type][:subscriptions][subscription.subscription_type][:description]
        # end

        description = subscription.adapter.description group.size, subscription, interest

        content << "- #{description}\n\n\n"

        group.each do |delivery|
          content << render_delivery(subscription, interest, delivery)
          content << "\n\n\n"
        end

        content << "\n"
      end

      content
    end

    def self.render_final(content)
      content << "----------------\nManage your subscriptions on the web at http://#{config[:hostname]}."
      content << "\n\nThese notifications are powered by the Sunlight Foundation (sunlightfoundation.com), a non-profit, non-partisan institution that uses cutting-edge technology and ideas to make government transparent and accountable."
      content << "\n\nYou may want to add this email address to your contact list to avoid your notifications being flagged as spam."
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
      if config[:email][:from].present?
        begin
          
          Pony.mail config[:email].merge(
            :to => email, 
            :subject => subject, 
            :body => content
          )
          
          true
        rescue Errno::ECONNREFUSED
          false
        end
      else
        puts "\n[USER] Would have delivered this to #{email}:"
        puts "\nSubject: #{subject}"
        puts "\n#{content}"
        true # if no 'from' email is specified, we'll assume it's a dev environment or something
      end
    end

  end
end
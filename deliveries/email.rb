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
          subject = "[Scout] #{interest_name interest} - new activity"

          if email_user email, subject, content
            deliveries.each &:delete
            successes << save_receipt!(user, deliveries, subject, content)
          else
            failures += 1
          end
        end

      if failures > 0
        Admin.report Report.failure("Delivery", "Failed to deliver #{failures} emails to #{email}")
      end

      if successes.any?
        Admin.report Report.success("Delivery", "Delivered #{successes.size} emails to #{email}")
      end

      successes
    end

    def self.save_receipt!(user, deliveries, subject, content)
      Receipt.create!(
        :deliveries => deliveries.map {|delivery| delivery.attributes.dup},

        :user_email => user.email,
        :user_delivery => user.delivery,

        :subject => subject,
        :content => content,
        :delivered_at => Time.now
      )
    end

      # one email containing everything
      #elsif frequency == 'digest'

                

      # else
      #   Admin.message "User #{email} has unsupported frequency (#{frequency}"
      #   return
      # end

    #   deliveries.group_by(&:subscription_interest_in).each do |interest_in, for_interest|
    #     grouped = for_interest.group_by &:subscription_type

    #     subject, content = render_email interest_in, for_interest, grouped
        
    #     if email_user(email, subject, content)
    #       for_interest.each do |delivery|
    #         delivery.destroy
    #       end

    #       # shouldn't be a risk of failure


    #       successes << receipt
    #     else
    #       failures += 1
    #     end
    #   end
    

    # deliveries are grouped by subscription object
    def self.render_interest(interest, deliveries)
      grouped = deliveries.group_by &:subscription

      content = ""
      grouped.each do |subscription, group|
        if interest.search?
          description = search_data[subscription.subscription_type][:description]
        else
          description = interest_data[interest.interest_type][:subscriptions][subscription.subscription_type][:description]
        end

        content << "- #{group.size} new #{description}\n\n\n"

        group.each do |delivery|
          item = Deliveries::SeenItemProxy.new(SeenItem.new(
            :item_id => delivery.item_id,
            :date => delivery.item_date,
            :data => delivery.item_data
          ))

          content << render_item(subscription, interest, item)
          content << "\n\n\n"
        end
        content << "\n"
      end

      content
    end

    def self.interest_name(interest)
      if interest.item?
        Subscription.adapter_for(interest_data[interest.interest_type][:adapter]).item_name(interest.data)
      else
        interest.in
      end
    end

    def self.render_final(content)
      content << "----------------\nManage your subscriptions on the web at http://#{config[:hostname]}."
      content << "\n\nThese notifications are powered by the Sunlight Foundation (sunlightfoundation.com), a non-profit, non-partisan institution that uses cutting-edge technology and ideas to make government transparent and accountable."
      content << "\n\nYou may want to add this email address to your contact list to avoid your notifications being flagged as spam."
      content
    end

    # render an item into its delivery content
    def self.render_item(subscription, interest, item)
      template = Tilt::ERBTemplate.new "views/subscriptions/#{subscription.subscription_type}/_email.erb"
      template.render item, :item => item, :subscription => subscription, :interest => interest, :trim => false
    end

    # def self.email_user(email, subject, )

    # internal
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
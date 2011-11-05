# should already be loaded as dependencies of sinatra
require 'erb'
require 'tilt'

module Subscriptions
  module Deliverance

    def self.deliver!
      delivereds = []

      # group by emails, send one per user per keyword
      emails = Delivery.all.distinct :user_email
      emails.each do |email|
        delivereds << deliver_for_user!(email)
      end

      # Temporary, but for now I want to know when emails go out
      if delivereds.size > 0
        msgs = delivereds.map(&:to_s).join "\n"
        Email.admin "Sent #{delivereds.size} emails among [#{emails.join ', '}]\n\n#{msgs}"
      end
    end

    def self.deliver_for_user!(email)
      failures = 0
      successes = []

      deliveries = Delivery.where(:user_email => email).all.to_a

      # group the deliveries by keyword
      deliveries.group_by(&:subscription_keyword).each do |keyword, for_keyword|
        grouped = for_keyword.group_by &:subscription_type

        subject, content = render_email keyword, for_keyword, grouped
        
        if Email.user(email, subject, content)
          for_keyword.each do |delivery|
            delivery.destroy
          end

          # shouldn't be a risk of failure
          delivered = Delivered.create!(
            :items => for_keyword.map {|d| d.item},
            :subscription_types => grouped.keys.inject({}) {|memo, key| memo[key] = grouped[key].size; memo},
            :delivered_at => Time.now,
            :keyword => keyword,
            :user_email => email,
            :subject => subject,
            :content => content
          )

          successes << delivered
        else
          failures += 1
        end
      end
      
      if failures > 0
        Email.report Report.failure("Delivery", "Failed to deliver #{failures} emails to #{email}")
      end

      successes
    end

    def self.render_email(keyword, deliveries, grouped)
      content = ""

      only_one = grouped.keys.size == 1
      descriptor = only_one ? subscription_data[grouped.keys.first.to_s][:description] : "things"

      subject = "#{keyword} - #{deliveries.size} new #{descriptor}"

      grouped.each do |type, group|
        unless only_one
          content << "- #{group.size} new #{subscription_data[type][:description]}\n\n\n"
        end

        group.each do |delivery|
          item = Subscriptions::Result.new(
            :id => delivery.item['id'],
            :date => delivery.item['date'],
            :data => delivery.item['data']
          )

          content << render_item(delivery.subscription_type, delivery.subscription_keyword, item)
          content << "\n\n\n"
        end
        content << "\n"
      end

      content << "----------------\nManage your subscriptions on the web at http://#{config[:hostname]}."
      content << "\n\nThese notifications are powered by the Sunlight Foundation (sunlightfoundation.com), a non-profit, non-partisan institution that uses cutting-edge technology and ideas to make government transparent and accountable."
      content << "\n\nYou may want to add this email address to your contact list to avoid your notifications being flagged as spam."

      return subject, content
    end

    def self.render_item(subscription_type, keyword, item)
      template = Tilt::ERBTemplate.new "views/subscriptions/#{subscription_type}/_email.erb"
      template.render item, :item => item, :keyword => keyword, :trim => false
    end

  end
end
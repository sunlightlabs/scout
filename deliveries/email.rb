# should already be loaded as dependencies of sinatra
require 'erb'
require 'tilt'

module Deliveries
  module Email

    # give these methods at the class level, since all the methods in here are class methods
    extend Helpers::Routing
    extend Helpers::Subscriptions

    def self.deliver_for_user!(user, frequency, options = {})
      dry_run = options['dry_run'] || false

      failures = []
      successes = []

      email = user.email
      header = Rendering.header user
      footer = Rendering.footer user
      from = from_for user
      reply_to = reply_to_for user

      conditions = {mechanism: "email", email_frequency: frequency}
      matching_deliveries = user.deliveries.where(conditions).desc("item.date").all
      interest_deliveries = matching_deliveries.group_by &:interest

      # if sending whenever, then send one email per-interest
      if frequency == 'immediate'

        interest_deliveries.each do |interest, deliveries|
          content = ""
          content << header
          content << render_interest(user, interest, deliveries)
          content << footer

          subject = render_subject interest, deliveries

          if dry_run
            ::Email.sent_message("DRY RUN", "User", email, subject, content, from, reply_to)
          else
            if email_user(email, subject, content, from, reply_to)
              # delete first, save receipt after, in case an error in
              # saving the receipt leaves the delivery around to be re-delivered
              serialized = serialize_deliveries deliveries
              deliveries.each &:delete
              successes << save_receipt!(frequency, user, serialized, subject, content)
            else
              failures << {frequency: frequency, email: email, subject: subject, content: content, interest_id: interest.id.to_s}
            end
          end
        end

      elsif frequency == 'daily' # digest all deliveries into one single email

        if matching_deliveries.any? # not sure why this would be the case, but, just in case
          content = ""
          content_pieces = []

          interest_deliveries.each do |interest, deliveries|
            content_pieces << render_interest(user, interest, deliveries)
          end

          content << content_pieces.join("\n\n")
          content << footer

          subject = daily_subject_for matching_deliveries.size, user

          if dry_run
            ::Email.sent_message("DRY RUN", "User", email, subject, content, from, reply_to)
          else
            if email_user(email, subject, content, from, reply_to)
              # delete first, save receipt after, in case an error in
              # saving the receipt leaves the delivery around to be re-delivered
              serialized = serialize_deliveries matching_deliveries
              matching_deliveries.each &:delete
              successes << save_receipt!(frequency, user, serialized, subject, content)
            else
              failures << {frequency: frequency, email: email, subject: subject, content: content, interest_id: interest.id.to_s}
            end
          end
        end
      end

      if failures.size > 0
        Admin.report Report.failure("Delivery", "Failed to deliver #{failures.size} emails to #{email}", failures: failures)
      end

      if successes.any?
        Report.success("Delivery", "Delivered #{successes.size} emails to #{email}")
      end

      successes
    end

    def self.deliver_custom!(user, interests, options = {})
      dry_run = options['dry_run'] || false

      failures = []
      successes = []

      email = user.email
      from = from_for user
      reply_to = reply_to_for user
      frequency = "custom"

      # provided interests already match the appropriate filter
      matching_deliveries = interests.map do |interest|
        interest.deliveries.where(subscription_type: "state_bills").desc("item.date").all
      end.flatten

      # re-group by interest
      interest_deliveries = matching_deliveries.group_by &:interest


      if matching_deliveries.any?
        content_pieces = []

        interest_deliveries.each do |interest, deliveries|
          content_pieces << render_interest(user, interest, deliveries)
        end

        content = content_pieces.join "\n\n"
        content << Rendering.footer(user)

        # prepend custom header if present
        if options['header']
          content = [options['header'], content].join "\n\n<hr/>\n\n"
        end

        if options['subject']
          subject = options['subject']
        else
          subject = "Daily digest - #{matching_deliveries.size} new #{matching_deliveries.size > 1 ? "results" : "result"}"
        end

        if dry_run
          ::Email.sent_message("DRY RUN", "User", email, subject, content)
        else
          if email_user(email, subject, content, from, reply_to)
            # delete first, save receipt after, in case an error in
            # saving the receipt leaves the delivery around to be re-delivered
            serialized = serialize_deliveries matching_deliveries
            matching_deliveries.each &:delete
            successes << save_receipt!(frequency, user, serialized, subject, content)
          else
            failures << {frequency: frequency, email: email, subject: subject, content: content, interest_id: interest.id.to_s}
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
        email_frequency: frequency,
        mechanism: "email",

        deliveries: deliveries,

        user_id: user.id,
        user_email: user.email,
        user_notifications: user.notifications,
        user_service: user.service,

        subject: subject,
        content: content,
        delivered_at: Time.now
      )
    end

    def self.serialize_deliveries(deliveries)
      deliveries.map {|delivery| delivery.attributes.dup}
    end

    def self.render_interest(user, interest, deliveries)
      grouped = deliveries.group_by &:subscription_type

      rendered = ""

      title = truncate interest_name(interest, long: true), 200
      rendered << Rendering.interest_title(title, interest.interest_type)

      content = []

      grouped.each do |subscription_type, group|
        one_content = ""

        # always plural, always capitalized
        description = Subscription.adapter_for(subscription_type).short_name 2, interest
        description = description.capitalize

        if interest.filters.any?
          filters = interest.filters.map do |field, value|
            interest.filter_name field, value
          end.join(", ")
          description << " (#{filters})"
        end

        one_content << Rendering.interest_subtitle(description)

        group.each do |delivery|
          one_content << Rendering.delivery(user, delivery, interest, subscription_type)
        end

        # wrap in section div for shading
        one_content = Rendering.section_for one_content

        content << one_content
      end

      rendered << content.join("\n\n")
    end

    # subject line for per-interest emails
    def self.render_subject(interest, deliveries)
      title = truncate interest_name(interest, long: true), 200
      subject = "#{title} - "

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

    def self.from_for(user)
      if user.service == "open_states"
        "Open States <openstates-alerts@sunlightfoundation.com>"
      else
        nil # will default to value in config.yml
      end
    end

    def self.reply_to_for(user)
      if user.service == "open_states"
        "Open States <openstates-alerts+yesreply@sunlightfoundation.com>"
      else
        nil # will default to value in config.yml
      end
    end

    def self.daily_subject_for(number, user)
      if user.service == "open_states"
        prefix = "Your Open States alerts"
      else
        prefix = "Scout daily digest"
      end
      suffix = "#{number} new #{number > 1 ? "results" : "result"}"

      "#{prefix} - #{suffix}"
    end

    # the actual mechanics of sending the email
    def self.email_user(email, subject, content, from = nil, reply_to = nil)
      ::Email.deliver! "User Alert", email, subject, content, from, reply_to
    end

    def self.truncate(string, length)
      string ||= ""
      if string.size > length
        string[0...length] + "…"
      else
        string
      end
    end



    # rendering pieces

    module Rendering

      extend Helpers::Routing
      extend Helpers::Subscriptions

      def self.footer(user); piece "footers", user; end
      def self.header(user); piece "headers", user; end

      def self.piece(piece, user)
        context = Deliveries::SeenItemProxy.new # dummy to get helpers
        template = Tilt::ERBTemplate.new "app/views/emails/#{piece}/#{user.service || "general"}.erb"
        rendered = template.render context, trim: false
        rendered.force_encoding "utf-8"
        rendered
      end

      # render a Delivery into its email content
      def self.delivery(user, delivery, interest, subscription_type)
        item = Deliveries::SeenItemProxy.new(SeenItem.new(delivery.item))

        # permalink to item, but wrapped up in a redirector
        url = email_item_url item, interest, user

        template = Tilt::ERBTemplate.new "app/views/subscriptions/#{subscription_type}/_email.erb"
        rendered = template.render item, user: user, item: item, interest: interest, url: url, trim: false
        rendered.force_encoding "utf-8"
        rendered
      end

      def self.interest_title(name, interest_type)
        <<-eos
        <div style="margin: 0; padding: 0; margin-top: 20px; margin-bottom: 0px; width: 100%; background-color: #238397; padding-left: 5px;">
          <h1 style="color: #FFF; font-family: 'helvetica Neue', arial, sans-serif; text-transform: uppercase; font-weight: 400; background-color: #238397; font-size: 200%; margin-top: 30px; margin-bottom: 0px; display: inline;">
            #{name}
          </h1>
          <span style="color: #CCC; font-size: 90%; font-style: italic;">
            #{
              if interest_type == "search"
                "You are following this search"
              elsif interest_type == "item"
                "You are following this bill"
              elsif interest_type == "feed"
                "You are following this feed"
              end
            }
          </span>
        </div>
        eos
      end

      def self.interest_subtitle(description)
        <<-eos
        <div style="margin-top: 35px; padding: 0;">
          <h2 style="color: #666; font-family: 'helvetica Neue', arial, sans-serif; text-transform: uppercase; font-weight: 500; font-size: 135%; background-color: #FFF; border-bottom-style: dotted; border-bottom-color: #CCC;">
            #{description}
          </h2>
        </div>
        eos
      end

      def self.section_for(html)
        <<-eos
        <div class="section" style="background-color: #FAFBF7;padding-bottom: 20px;">
          #{html}
        </div>
        eos
      end

    end

  end
end

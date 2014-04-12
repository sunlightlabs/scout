# some helpful test tasks

namespace :test do

  desc "Say what the app believes is the current environment"
  task env: :environment do
    puts "Current environment: #{Sinatra::Base.environment}"
  end

  # based on raven test, so we can depend on environment being loaded
  desc "Send a test Sentry event"
  task sentry: :environment do
    Raven::CLI.test Environment.config['sentry']
  end

  desc "Send a test email to the admin"
  task email_admin: :environment do
    message = ENV['msg'] || "Test message. May you receive this in good health."
    Admin.message message
  end

  desc "Send three test reports"
  task email_report: :environment do
    Admin.report Report.failure("Admin.report 1", "Testing regular failure reports.", {name: "test report"})
    Admin.report Report.exception("Admin.report 2", "Testing exception reports", Exception.new("WOW! OUCH!!"))
    Admin.exception "Admin.report 3", Exception.new("OH MAN!!!"), {extra: "information"}
  end

  desc "Creates an item subscription for a user"
  task follow_item: :environment do
    unless (item_id = ENV['item_id']).present? and (item_type = ENV['item_type']).present?
      puts "Provide an item_type and item_id"
      exit -1
    end

    unless user = User.where(email: (ENV['email'] || Environment.config['admin'].first)).first
      puts "Provide an email of a registered user."
      exit -1
    end

    interest = Interest.for_item user, item_id, item_type
    unless interest.new_record?
      puts "User already subscribed to that item."
      exit -1
    end

    adapter = if item_types[item_type] and item_types[item_type]['adapter']
      item_types[item_type]['adapter']
    else
      item_type.pluralize
    end

    unless item = Subscriptions::Manager.find(adapter, item_id)
      puts "Couldn't find remote information about the item."
      exit -1
    end

    interest.data = item.data

    if ENV['tags'].present?
      interest.tags = ENV['tags'].split ","
    end

    interest.save!

    puts "User subscribed to #{item_type} with ID: #{item_id}"
  end

  desc "Forces emails to be sent for the first X results of every subscription a user has"
  task send_user: :environment do
    email = ENV['email'] || Environment.config['admin'].first

    max = (ENV['max'] || ENV['limit'] || 2).to_i
    only = (ENV['only'] || "").split(",")
    interest_in = (ENV['interest_in'] || "").split(",")

    citation = ENV['citation']

    function = (ENV['function'] || :check).to_sym

    mechanism = 'email'
    email_frequency = ENV['frequency'] || 'immediate'

    unless ['immediate', 'daily'].include?(email_frequency)
      puts "Use 'immediate' or 'daily' for a frequency."
      return
    end

    unless user = User.where(email: email).first
      puts "Can't find user by that email."
      exit -1
    end

    puts "Clearing all deliveries for #{user.email}"
    user.deliveries.delete_all

    user.interests.each do |interest|
      interest.subscriptions.each do |subscription|
        if only.any?
          next unless only.include?(subscription.subscription_type)
        end

        if citation
          next unless subscription.data['citation_id'] == citation
        end

        if interest_in.any?
          next unless interest_in.include?(subscription.interest_in)
        end

        puts "Searching for #{subscription.subscription_type} results for #{interest.in}..."
        items = Subscriptions::Manager.poll subscription, function, per_page: max
        if items.nil? or items.empty?
          puts "No results, nothing to deliver."
          next
        elsif items.is_a?(Hash)
          puts "ERROR searching:\n\n#{JSON.pretty_generate items}"
          next
        end

        followers = interest.followers

        items.first(max).each do |item|
          delivery = Deliveries::Manager.schedule_delivery! item, interest, subscription.subscription_type, nil, mechanism, email_frequency

          if ENV['include_followers'].present?
            followers.each do |follower|
              Deliveries::Manager.schedule_delivery! item, interest, subscription.subscription_type, follower, mechanism, email_frequency
            end
          end
        end
      end

    end

    # scopes deliveries to a particular email, using Delivery#user_email.
    # The Delivery#user_email field is for TESTING/DEBUGGING only,
    # during real delivery, the user's email should get looked up again,
    # at the instant of delivery, in case it's changed between scheduling
    # and delivery.
    Deliveries::Manager.deliver!(
      "mechanism" => mechanism,
      "email_frequency" => email_frequency,
      "user_email" => email
    )
  end

  desc "Deliver an individual delivery (use 'id' parameter)"
  task delivery: :environment do
    id = ENV['id']
    if delivery = Delivery.find(id)
      Deliveries::Manager.deliver! '_id' => id, 'mechanism' => delivery.mechanism, 'email_frequency' => delivery.email_frequency
    else
      puts "Couldn't locate delivery by provided ID"
    end
  end

end

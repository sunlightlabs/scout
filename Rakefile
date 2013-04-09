task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require './config/environment'
end

# does not hinge on the environment, test_helper loads it itself
task default: :test
task :test do
  responses = Dir.glob("test/**/*_test.rb").map do |file|
    puts "\nRunning #{file}:\n"
    system "ruby #{file}"
  end
  
  if responses.any? {|code| code == false}
    puts "\nFAILED\n"
    exit -1
  else
    puts "\nSUCCESS\n"
    exit 0
  end
end

desc "Set the crontab in place for this environment"
task :set_crontab => :environment do
  environment = ENV['environment']
  current_path = ENV['current_path']
  
  if environment.blank? or current_path.blank?
    Admin.message "No environment or current path given, emailing and exiting."
    next
  end
  
  if system("cat #{current_path}/config/cron/#{environment}/crontab | crontab")
    puts "Successfully overwrote crontab."
  else
    Admin.report Report.warning("Crontab", "Crontab overwriting failed on deploy.")
    puts "Unsuccessful in overwriting crontab, emailed report."
  end
end

desc "Disable/clear the crontab for this environment"
task :disable_crontab => :environment do
  if system("echo | crontab")
    puts "Successfully disabled crontab."
  else
    Admin.message "Somehow failed at disabling crontab."
    puts "Unsuccessful (somehow) at disabling crontab, emailed report."
  end
end

desc "Run through each model and create all indexes" 
task :create_indexes => :environment do
  begin
    models = Dir.glob('app/models/*.rb').map do |file|
      File.basename(file, File.extname(file)).camelize.constantize
    end

    raise Exception.new("What? No models") if models.empty?

    models.each do |model|
      if model.respond_to?(:create_indexes) 
        model.create_indexes
        puts "Created indexes for #{model}"
      end
    end
    
  rescue Exception => ex
    report = Report.exception 'Indexes', "Exception creating indexes", ex
    Admin.report report
    puts "Error creating indexes, emailed report."
  end
end

desc "Clear the database"
task :clear_data => :environment do
  models = Dir.glob('app/models/*.rb').map do |file|
    File.basename(file, File.extname(file)).camelize.constantize
  end
  
  models.each do |model| 
    model.delete_all
    puts "Cleared model #{model}."
  end
end

subscription_types = Dir.glob('subscriptions/adapters/*.rb').map do |file|
  File.basename file, File.extname(file)
end

namespace :subscriptions do

  # don't run this from the command line - modify for individual tasks
  task :generate => :environment do
    item_type = ENV['item_type']
    subscription_type = ENV['subscription_type']

    return unless subscription_type.present?

    if item_type.present?
      Interest.where(item_type: item_type).each do |interest|
        # force a new subscription to be returned even if the interest is a saved record
        Interest.subscription_for(interest, subscription_type, true).save!
      end
    else # assume this is a search type
      Interest.where(search_type: "all").each do |interest|
        # force a new subscription to be returned even if the interest is a saved record
        Interest.subscription_for(interest, subscription_type, true).save!
      end
    end
  end

  desc "Try to initialize any uninitialized subscriptions"
  task :reinitialize => :environment do
    errors = []
    successes = []
    count = 0

    timer = (ENV['minutes'] || 25).to_i

    start = Time.now

    Subscription.uninitialized.each do |subscription|
      result = Subscriptions::Manager.initialize! subscription
      if result.nil? or result.is_a?(Hash)
        errors << result
      else
        successes << subscription
      end

      # no more than 25 (default) minutes' worth
      break if (Time.now - start) > timer.minutes
    end

    if errors.size > 0 # any? apparently returns false if the contents are just nils!
      Admin.report Report.warning(
        "Initialize", "#{errors.size} errors while re-initializing subscriptions, will try again later.", 
        errors: errors,
        )
    end

    if successes.size > 0
      Admin.report Report.success "Initialize", "Successfully initialized #{successes.size} previously uninitialized subscriptions.", subscriptions: successes.map {|s| s.attributes.dup}
    else
      puts "Did not re-initialize any subscriptions."
    end
  end
  
  namespace :check do

    subscription_types.each do |subscription_type|

      desc "Check for new #{subscription_type} items for initialized subscriptions"
      task subscription_type.to_sym => :environment do
        begin
          rate_limit = ENV['rate_limit'].present? ? ENV['rate_limit'].to_f : 0.1
          
          count = 0
          errors = []
          start = Time.now

          puts "Clearing all caches for #{subscription_type}..."
          Subscriptions::Manager.uncache! subscription_type


          criteria = {subscription_type: subscription_type}

          if ENV['email'] 
            if user = User.where(email: ENV['email']).first
              criteria[:user_id] = user.id
            else
              puts "Not a valid email, ignoring."
              return
            end
          end

          Subscription.initialized.where(criteria).each do |subscription|
            if subscription.user.confirmed?
              
              result = Subscriptions::Manager.check!(subscription)
              count += 1

              if rate_limit > 0
                sleep rate_limit
                puts "sleeping for #{rate_limit}"
              end

              if result.nil? or result.is_a?(Hash)
                errors << result
              end
            end
          end

          if errors.any?
            Admin.report Report.warning(
              "check:#{subscription_type}", "#{errors.size} errors while checking #{subscription_type}, will check again next time.", 
              errors: errors[0..2],
            )
          end

          Report.complete(
            "check:#{subscription_type}", "Completed checking #{count} #{subscription_type} subscriptions", elapsed_time: (Time.now - start)
          )

        rescue Exception => ex
          Admin.report Report.exception("check:#{subscription_type}", "Problem during 'rake subscriptions:check:#{subscription_type}'.", ex)
          puts "Error during subscription checking, emailed report."
        end
      end
    end

    desc "Check all subscription types right now (admin usage)"
    task :all => subscription_types.map {|type| "subscriptions:check:#{type}"} do
    end

  end
end
  
namespace :deliver do

  desc "Custom delivery task"
  task :custom => :environment do
    interest_options = {
      "interest_type" => "search",
      "search_type" => {"$in" => ["all", "state_bills"]}
    }

    subject = "State bill alerts for 2013 so far"
    header = File.read("misc/header.htm")

    Deliveries::Manager.custom_email!(
      subject, header,
      interest_options
    )
  end

  desc "Deliveries for a single daily email digest"
  task :email_daily => :environment do
    delivery_options = {"mechanism" => "email", "email_frequency" => "daily"}
    
    if ENV['email']
      delivery_options["user_email"] = ENV['email'].strip
    end

    begin
      Deliveries::Manager.deliver! delivery_options
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:email_daily.", ex)
      puts "Error during delivery, emailed report."
    end
  end

  desc "Deliveries of emails for whenever, per-interest"
  task :email_immediate => :environment do
    delivery_options = {"mechanism" => "email", "email_frequency" => "immediate"}
    
    if ENV['email']
      delivery_options["user_email"] = ENV['email'].strip
    end

    begin
      Deliveries::Manager.deliver! delivery_options
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:email_immediate.", ex)
      puts "Error during delivery, emailed report."
    end
  end

  desc "Deliveries of SMSes for whenever, per-interest"
  task :sms => :environment do
    begin
      Deliveries::Manager.deliver! "mechanism" => "sms"
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:sms.", ex)
      puts "Error during delivery, emailed report."
    end
  end
end

# some helpful test tasks to exercise emails and SMS

namespace :test do

  desc "Send a test email to the admin"
  task :email_admin => :environment do
    message = ENV['msg'] || "Test message. May you receive this in good health."
    Admin.message message
  end

  desc "Send two test reports"
  task :email_report => :environment do
    Admin.report Report.failure("Admin.report 1", "Testing regular failure reports.", {:name => "test report"})
    Admin.report Report.exception("Admin.report 2", "Testing exception reports", Exception.new("WOW! OUCH!!"))
  end

  desc "Send a test SMS"
  task :sms => :environment do
    message = ENV['msg'] || "Test SMS. May you receive this in good health."
    number = ENV['number']

    unless number.present?
      puts "Include a 'number' parameter."
      return
    end

    ::SMS.deliver! "Test", number, message
  end

  desc "Creates an item subscription for a user"
  task follow_item: :environment do
    unless (item_id = ENV['item_id']).present? and (item_type = ENV['item_type']).present?
      puts "Provide an item_type and item_id"
      exit -1
    end

    unless user = User.where(email: (ENV['email'] || config[:admin].first)).first
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

  desc "Forces emails or SMSes to be sent for the first X results of every subscription a user has"
  task send_user: :environment do
    email = ENV['email'] || config[:admin].first
    phone = ENV['phone']

    max = (ENV['max'] || ENV['limit'] || 2).to_i
    only = (ENV['only'] || "").split(",")
    interest_in = (ENV['interest_in'] || "").split(",")

    citation = ENV['citation']

    function = (ENV['function'] || :check).to_sym

    mechanism = ENV['by'] || (phone.present? ? 'sms' : 'email')
    email_frequency = ENV['frequency'] || 'immediate'

    unless ['immediate', 'daily'].include?(email_frequency)
      puts "Use 'immediate' or 'daily' for a frequency."
      return
    end

    user = nil
    if phone.present?
      user = User.by_phone phone
    else
      user = User.where(:email => email).first
    end

    unless user
      puts "Can't find user by that email or phone."
      exit -1
    end

    puts "Clearing all deliveries for #{user.email || user.phone}"
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

    Deliveries::Manager.deliver! "mechanism" => mechanism, "email_frequency" => email_frequency
  end

  desc "Deliver an individual delivery (use 'id' parameter)"
  task :delivery => :environment do
    id = ENV['id']
    if delivery = Delivery.find(id)
      Deliveries::Manager.deliver! '_id' => id, 'mechanism' => delivery.mechanism, 'email_frequency' => delivery.email_frequency
    else
      puts "Couldn't locate delivery by provided ID"
    end
  end

  namespace :remote do

    desc "Test remote subscription via SMS"
    task :subscribe => :environment do
      unless (phone = ENV['phone']).present?
        puts "Give a phone number with the 'phone' parameter."
      end
      item_type = ENV['item_type'] || 'bill'
      item_id = ENV['item_id'] || 'hr1234-112'
      hostname = ENV['host'] || config[:hostname]

      url = "#{hostname}/remote/subscribe/sms"

      response = HTTParty.post url, {body: {phone: phone, interest_type: "item", item_type: item_type, item_id: item_id}}
      puts "Status: #{response.code}"
      if response.code == 200
        puts "Body: #{JSON.pretty_generate JSON.parse(response.body)}"
      else
        puts "Body: #{response.body}"
      end
    end

    desc "Test confirmation of remote account, via SMS"
    task :confirm => :environment do
      unless (phone = ENV['phone']).present?
        puts "Give a phone number with the 'phone' parameter."
      end
      hostname = ENV['host'] || config[:hostname]

      url = "#{hostname}/remote/subscribe/sms"
    end
  end

end

desc "Clear all cached content."
task :clear_cache => :environment do
  Cache.delete_all
  puts "Cleared cache."
end


# depends on misc/usc.json having the structure of the US Code
# as output by the github.com/unitedstates/uscode project:
#
#   ./run structure --sections > usc.json

desc "Load in the structure of the US Code."
namespace :usc do
  task :load => :environment do
    only = ENV['title'] || nil

    titles = MultiJson.load open("misc/usc.json")

    titles.each do |title|
      next if only and (title['number'].to_s != only.to_s)
      next if title['number']["a"] # skip appendices, too complicated

      title['subparts'].each do |section|
        puts "[#{section['citation']}] Processing..."

        cite = Citation.find_or_initialize_by citation_id: section['citation']
        cite.description = section['name']
        cite.usc['title'] = title['number']
        cite.usc['section'] = section['number']
        cite.save!
      end
    end
  end
end
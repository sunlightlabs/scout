task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require './config/environment'
end

# does not hinge on the environment, test_helper loads it itself
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
    Admin.message "Crontab overwriting failed on deploy."
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
    models = Dir.glob('models/*.rb').map do |file|
      File.basename(file, File.extname(file)).camelize.constantize
    end

    models.each do |model| 
      model.create_indexes 
      puts "Created indexes for #{model}"
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
  
  namespace :check do

    subscription_types.each do |subscription_type|

      desc "Check for new #{subscription_type} items for initialized subscriptions"
      task subscription_type.to_sym => :environment do
        begin
          Subscription.initialized.where(:subscription_type => subscription_type).each do |subscription|
            if subscription.user.confirmed?
              Subscriptions::Manager.check! subscription
            end
          end
        rescue Exception => ex
          Admin.report Report.exception("Check", "Problem during 'rake subscriptions:check:#{subscription_type}'.", ex)
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
  desc "Deliveries for a single daily email digest"
  task :email_daily => :environment do
    begin
      Deliveries::Manager.deliver! "mechanism" => "email", "email_frequency" => "daily"
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:email_daily.", ex)
      puts "Error during delivery, emailed report."
    end
  end

  desc "Deliveries of emails for whenever, per-interest"
  task :email_immediate => :environment do
    begin
      Deliveries::Manager.deliver! "mechanism" => "email", "email_frequency" => "immediate"
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

  desc "Forces emails or SMSes to be sent for the first X results of every subscription a user has"
  task :send_user => :environment do
    email = ENV['email'] || config[:admin].first
    max = (ENV['max'] || ENV['limit'] || 2).to_i
    only = (ENV['only'] || "").split(",")
    keywords = (ENV['keywords'] || "").split(",")

    mechanism = ENV['by'] || 'email'
    email_frequency = ENV['frequency'] || 'immediate'

    unless ['immediate', 'daily'].include?(email_frequency)
      puts "Use 'immediate' or 'daily' for a frequency."
      return
    end

    unless user = User.where(:email => email).first
      puts "Can't find user by that email."
      return
    end

    puts "Clearing all deliveries for #{email}"
    Delivery.where(:user_email => email).delete_all

    user.interests.each do |interest|
      interest.subscriptions.each do |subscription|
        if only.any?
          next unless only.include?(subscription.subscription_type)
        end

        if keywords.any?
          next unless keywords.include?(subscription.interest_in)
        end

        puts "Searching for #{subscription.subscription_type} results for #{interest.in}..."
        items = subscription.search
        if items.nil? or items.empty?
          puts "\tNo results, nothing to deliver."
          next
        end

        items.first(max).each do |item|
          delivery = Deliveries::Manager.schedule_delivery! item, subscription, mechanism, email_frequency
        end
      end

    end

    Deliveries::Manager.deliver! "mechanism" => mechanism, "email_frequency" => email_frequency
  end

  desc "Deliver an individual delivery (use 'id' parameter)"
  task :delivery => :environment do
    id = ENV['id']
    if delivery = Delivery.find(id)
      Deliveries::Manager.deliver! '_id' => BSON::ObjectId(id), 'mechanism' => delivery.mechanism, 'email_frequency' => delivery.email_frequency
    else
      puts "Couldn't locate delivery by provided ID"
    end
  end

end
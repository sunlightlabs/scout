task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'config/environment'
end

desc "Set the crontab in place for this environment"
task :set_crontab => :environment do
  environment = ENV['environment']
  current_path = ENV['current_path']
  
  if environment.blank? or current_path.blank?
    Admin.message "No environment or current path given, emailing and exiting."
    exit
  end
  
  if system("cat #{current_path}/config/cron/#{environment}/crontab | crontab")
    puts "Successfully overwrote crontab."
  else
    Admin.message "Crontab overwriting failed on deploy."
    puts "Unsuccessful in overwriting crontab, emailed report."
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
  models = Dir.glob('models/*.rb').map do |file|
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
            Subscriptions::Manager.check! subscription
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
  desc "Users who want a single daily email digest"
  task :email_digest => :environment do
    Deliveries::Manager.deliver! "delivery.mechanism" => "email", "delivery.email_frequency" => "daily"
  end

  desc "Users who want emails whenever, per-interest"
  task :email_immediate => :environment do
    Deliveries::Manager.deliver! "delivery.mechanism" => "email", "delivery.email_frequency" => "immediate"
  end
end

# some helpful test tasks to exercise emails 

namespace :test do

  desc "Send a test email to the admin"
  task :email_admin => :environment do
    Admin.message "Test message. May you receive this in good health."
  end

  desc "Send two test reports"
  task :email_report => :environment do
    Admin.report Report.failure("Admin.report 1", "Testing regular failure reports.", {:name => "test report"})
    Admin.report Report.exception("Admin.report 2", "Testing exception reports", Exception.new("WOW! OUCH!!"))
  end

  desc "Forces emails to be sent for the first X results of every subscription a user has"
  task :email_user => :environment do
    email = ENV['email'] || config[:admin][:email]
    max = (ENV['max'] || ENV['limit'] || 2).to_i

    unless user = User.where(:email => email).first
      puts "Can't find user by that email."
      return
    end

    puts "Clearing deliveries for #{email}"
    Delivery.where(:user_email => email).delete_all

    user.interests.each do |interest|
      interest.subscriptions.each do |subscription|

        puts "Searching for #{subscription.subscription_type} results for #{interest.in}..."
        items = subscription.search
        if items.empty?
          puts "\tNo results, nothing to deliver."
          next
        end

        items.first(max).each do |item|
          delivery = Deliveries::Manager.schedule_delivery! subscription, item
        end
      end

    end

    Deliveries::Manager.deliver! :email => email
  end

end
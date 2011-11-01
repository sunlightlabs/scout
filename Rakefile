task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'config/environment'
end

desc "Run through each model and create all indexes" 
task :create_indexes => :environment do
  begin
    models = Dir.glob('models/*.rb').map do |file|
      File.basename(file, File.extname(file)).camelize.constantize
    end
    
    # DEBUG
    raise Exception.new

    models.each do |model| 
      model.create_indexes 
      puts "Created indexes for #{model}"
    end
    
  rescue Exception => ex
    report = Report.exception 'Indexes', "Exception creating indexes", ex
    Email.report report
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

namespace :subscriptions do
  
  desc "Check for new items for every active, initialized subscription"
  task :check => :environment do
    begin
      Subscription.initialized.all.each do |subscription|
        Subscriptions::Manager.check! subscription
      end
    rescue Exception => ex
      report = Report.exception "Check", "Problem during 'rake subscriptions:check'.", ex
      Email.report report
      puts "Error during subscription checking, emailed report."
    end
  end
  
  namespace :deliver do

    desc "Deliver outstanding emails, grouped by keywords"
    task :email => :environment do
      begin
        Subscriptions::Deliverance.deliver!      
      rescue Exception => ex
        Email.report Report.exception("Delivery", "Problem during 'rake subscriptions:deliver'.", ex)
        puts "Error during delivery, emailed report."
      end
    end
  end
  
end

# some helpful test tasks to exercise emails 

namespace :test do

  desc "Send a test email to the admin"
  task :email_admin => :environment do
    Email.admin "Test message. May you receive this in good health."
  end

  desc "Send two test reports"
  task :email_report => :environment do
    Email.report Report.failure("Email.report 1", "Testing regular failure reports.", {:name => "test report"})
    Email.report Report.exception("Email.report 2", "Testing exception reports", Exception.new("WOW! OUCH!!"))
  end

  desc "Send a test report of a subscription"
  task :email_result => :environment do
    types = ENV['type'].split(",")
    keywords = ENV['keyword'].split(",")
    email = ENV['email']
    max = ENV['max'] || 2

    if types.empty? or keywords.empty?
      puts "Enter 'type' and 'keyword' parameters."
      return
    end

    unless admin = User.where(:email => email).first
      puts "Can't find user by that email."
      return
    end

    # clear out any deliveries for this user
    Delivery.where(:user_email => email).delete_all

    keywords.each do |keyword|
      types.each do |type|

        subscription = admin.subscriptions.new(
          :keyword => keyword,
          :subscription_type => type
        )

        puts "Searching for #{type} results for #{keyword}..."
        results = subscription.search
        if results.empty?
          puts "\tNo results, nothing to deliver."
          return
        end

        results.first(max).each do |result|
          delivery = Subscriptions::Manager.schedule_delivery! subscription, result
        end
      end

    end

    Subscriptions::Deliverance.deliver_for_user! email

  end

end
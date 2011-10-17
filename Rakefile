task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'config/environment'
  
  require 'pony'
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
    email_message "Exception creating indexes.", ex
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
      email_message "Problem during 'rake subscriptions:check'.", ex
      puts "Error during subscription checking, emailed report."
    end
  end
  
  desc "Deliver outstanding queued items, grouped by user"
  task :deliver => :environment do
    begin
      # should already be loaded as dependencies of sinatra
      require 'erb'
      require 'tilt'
      
      failures = []
      successes = 0
      
      emails = Delivery.all.distinct :user_email
      
      # group by emails, send one to each user
      emails.each do |email|
        
        deliveries = Delivery.where(:user_email => email).all.to_a
        content = render_email deliveries
        
        if email_user(email, content)
        
          deliveries.each do |delivery|
            delivery.destroy
          end
        
          # shouldn't be a risk of failure
          delivered = Delivered.create!(
            :deliveries => deliveries.map {|d| d.attributes},
            :delivered_at => Time.now,
            :user_email => email,
            :content => content
          )
          
          successes += 1
        else
          failures << "Couldn't send an email to #{email}"
        end
        
      end
      
      if failures.any?
        report = Report.failure "Delivery", "Failed to deliver #{failures.size} deliveries"
      end
      
      if successes > 0
        report = Report.success "Delivery", "Delivered #{successes} emails."
        
        # Temporary, but for now I want to know when emails go out
        email_message "Sent #{successes} emails among [#{emails.join ', '}]"
      else
        puts "No emails to deliver."
      end
      
    rescue Exception => ex
      email_message "Problem during 'rake subscriptions:deliver'.", ex
      puts "Error during delivery, emailed report."
    end
  end
  
end


def render_email(deliveries)
  content = ""
  
  # group the deliveries by keyword
  groups = {}
  
  deliveries.each do |delivery|
    item = Subscriptions::Item.new(
      :id => delivery.item['id'], 
      :data => delivery.item['data']
    )
    
    keyword = delivery.subscription_keyword
    
    groups[keyword] ||= []
    groups[keyword] << [delivery.subscription, item]
  end
  
  groups.keys.each do |keyword|
    content << "<h1>#{keyword}</h1>"
    
    groups[keyword].each do |subscription, item|
      content << render_item(subscription, item)
    end
  end
  
  content
end

def render_item(subscription, item)
  template = Tilt::ERBTemplate.new "views/subscriptions/#{subscription.subscription_type}/_email.erb"
  template.render item, :item => item, :subscription => subscription
end

def email_user(email, content)
  if config[:email][:from].present?
    begin
      subject = "[Alarm Site] Latest alerts"
      
      Pony.mail config[:email].merge(
        :to => email, 
        :subject => subject, 
        :html_body => content
      )
      
      true
    rescue Errno::ECONNREFUSED
      false
    end
  else
    puts "\n[USER EMAIL] Delivery to #{email}"
    true # if no email is specified, we'll assume it's a dev environment or something
  end
end

def email_report(report)
  subject = "[#{report.status}] #{report.source} | #{report.message}"
    
  body = ""
  body += exception_message(report[:exception]) if report[:exception]
  
  attrs = report.attributes.dup
  [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}
  
  body += attrs.inspect
    
  if config[:admin][:email].present?
    begin
      Pony.mail config[:email].merge(
        :subject => subject, 
        :body => body,
        :to => config[:admin][:email]
      )
    rescue Errno::ECONNREFUSED
      puts "Couldn't email report, connection refused! Check system settings."
    end
  else
    puts "\n[ADMIN EMAIL] #{body}"
  end
end

def email_message(msg, exception = nil)
  body = exception ? exception_message(exception) : msg
  subject = "[#{exception ? "ERROR" : "ADMIN"}] #{msg}"
  
  if config[:admin][:email].present?
    begin
      Pony.mail config[:email].merge(
        :subject => subject,
        :body => body,
        :to => config[:admin][:email]
      )
    rescue Errno::ECONNREFUSED
      puts "Couldn't email message, connection refused! Check system settings."
    end
  else
    puts "\n[ADMIN EMAIL] #{body}"
  end
end

def exception_message(exception)
  type = exception.class.to_s
  message = exception.message
  backtrace = exception.backtrace
  
  msg = ""
  msg += "#{type}: #{message}" 
  msg += "\n\n"
  
  if backtrace.respond_to?(:each)
    backtrace.each {|line| msg += "#{line}\n"}
    msg += "\n\n"
  end
  
  msg
end
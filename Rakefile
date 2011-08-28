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
    
    models.each do |model| 
      if model.respond_to? :create_indexes
        model.create_indexes 
        puts "Created indexes for #{model}"
      else
        puts "Skipping #{model}, not a Mongoid model"
      end
    end
  rescue Exception => ex
    email_message "Exception creating indexes, message and backtrace attached", {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}
    puts "Error creating indexes, emailed report."
  end
end


# subscription management tasks
# most of this work is encapsulated inside the Subscriptions::Manager (/subscriptions/manager.rb)

namespace :subscriptions do
  
  desc "Poll for new items for every active, initialized subscription"
  task :poll => :environment do
    Subscription.initialized.all.each do |subscription|
      Subscriptions::Manager.check! subscription
    end
  end
  
  desc "Deliver outstanding queued items, grouped by user"
  task :deliver => :environment do
    # should be in as dependencies of sinatra
    require 'erb'
    require 'tilt'
    
    failures = []
    successes = 0
    
    # group by emails, send one to each user
    Delivery.all.distinct(:user_email).each do |email|
      
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
    else
      puts "No emails to deliver."
    end
    
  end  

end

def render_email(deliveries)
  content = ""
  
  # group the deliveries by keyword
  groups = {}
  
  deliveries.each do |delivery|
    item = Subscriptions::Item.new :id => delivery.item['id'], :data => delivery.item['data']
    groups[item.data['keyword']] ||= []
    groups[item.data['keyword']] << item
  end
  
  groups.keys.each do |keyword|
    content << "<h1>#{keyword}</h1>"
    
    groups[keyword].each do |item|
      content << render_item(item)
    end
  end
  
  content
end

def render_item(item)
  template = Tilt::ERBTemplate.new "views/subscriptions/_email_item.erb"
  template.render item, :item => item
end

def email_user(email, content)
  if config[:email][:from].present?
    begin
      
      true
    rescue Errno::ECONNREFUSED
      false
    end
  else
    puts "Would have emailed something to #{email}"
    true # if no email is specified, we'll assume it's a dev environment or something
  end
end

def email_report(report)
  if config[:email][:to] and config[:email][:to].any?
    
    subject = "[#{report.status}] #{report.source} | #{report.message}"
    
    body = ""
    body += exception_message(report[:exception]) if report[:exception]
    
    attrs = report.attributes.dup
    [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}
    
    body += attrs.inspect
    
    begin
      Pony.mail config[:email].merge(:subject => subject, :body => body)
    rescue Errno::ECONNREFUSED
      puts "Couldn't email report, connection refused! Check system settings."
    end
  end
end

def email_message(msg, exception)
  if config[:email][:to] and config[:email][:to].any?
    begin
      Pony.mail config[:email].merge(:subject => msg, :body => (exception ? exception_message(exception) : msg))
    rescue Errno::ECONNREFUSED
      puts "Couldn't email message, connection refused! Check system settings."
    end
  end
end

def exception_message(exception)
  msg = ""
  msg += "#{exception['type']}: #{exception['message']}" 
  msg += "\n\n"
  
  if exception['backtrace'] and exception['backtrace'].respond_to?(:each)
    exception['backtrace'].each {|line| msg += "#{line}\n"}
    msg += "\n\n"
  end
  
  msg
end
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

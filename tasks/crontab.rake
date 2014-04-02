namespace :crontab do
  desc "Set the crontab in place for this environment"
  task set: :environment do
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
  task disable: :environment do
    if system("echo | crontab")
      puts "Successfully disabled crontab."
    else
      Admin.message "Somehow failed at disabling crontab."
      puts "Unsuccessful (somehow) at disabling crontab, emailed report."
    end
  end

  desc "Warning to admin that the crontab is still disabled"
  task warn: :environment do
    Admin.message("WARNING: just so you know: the crontab is still disabled.")
    puts "Warned administrator that the crontab is still disabled."
  end
end
namespace :users do

  desc "Change a user's email"
  task update_email: :environment do
    email = ENV['email']
    user = User.where(email: email).first if email.present?

    new_email = ENV['new_email']

    unless user and new_email.present?
      puts "Specify valid 'email' and 'new_email' parameters."
      exit
    end

    user.email = new_email
    user.save!
    puts "Updated user."

    user.deliveries.update_all user_email: new_email
    puts "Updated #{user.deliveries.count} pending deliveries."
  end
  
  desc "Turn on/off all notifications for a user. Defaults to turning off"
  task change_notifications: :environment do
    if not ENV['email'].present?
      puts "Must provide 'email' environmental argument. Optionally include 'notifications' and 'announcements'"
      puts "Example: rake change_notifications email=user@example.com notifications=none announcements=false"
    elsif not ['none','email_daily','email_immediate'].include?(ENV['notifications'])
      puts "Notifications argument must be in [none, email_daily, email_immediate]"
    else
      email = ENV['email']
      user = User.where(email: email).first if email.present?
      user.notifications = ENV['notifications'].present? ? ENV['notifications'] : 'none'
      if ENV['announcements'].present?
        bool = ENV['announcements'] == 'false' ? false : true
        user.announcements = bool
        user.sunlight_announcements = bool
      else
        user.announcements = false
        user.sunlight_announcements = false
      end
      
      user.save
    end
  end
    
end

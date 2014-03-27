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

end
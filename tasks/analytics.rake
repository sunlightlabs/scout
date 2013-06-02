namespace :analytics do

  desc "Daily report on various things."
  task daily: :environment do
    msg = daily_report "2013-05-30"
    puts msg
  end

  def daily_report(day)
    msg = ""

    start_time = Time.zone.parse(day).midnight # midnight Eastern time
    end_time = start_time + 1.day
    ending = end_time.strftime "%Y-%m-%d"

    users = User.asc(:created_at).for_time day, ending
    interests = Interest.for_time day, ending
    unsubscribes = Event.where(type: "unsubscribe-alert").for_time day, ending
    receipts = Receipt.where(mechanism: "email").for_time day, ending

    msg << "- #{start_time.strftime("%B %d, %Y")}\n"
    msg << "\n"

    msg << "#{users.count} new users\n"
    msg << "#{interests.count} alerts created across all users\n"
    msg << "#{unsubscribes.count} alerts removed across all users\n"
    msg << "#{receipts.count} delivered emails across all users"

    msg << "\n\n"
  end
end
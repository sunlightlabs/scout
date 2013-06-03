namespace :analytics do

  desc "Daily report on various things."
  task daily: :environment do

    day = ENV['day'] || Time.now.strftime("%Y-%m-%d")

    msg = ""
    msg += general_report day
    msg += google_report day
    puts msg
  end

  task google: :environment do
    day = ENV['day'] || Time.now.strftime("%Y-%m-%d")
    msg = google_report day
    Admin.message "Google Report for #{day}", msg
  end

  def google_report(day)
    start_time = Time.zone.parse(day).midnight # midnight Eastern time
    end_time = start_time + 1.day


    hits = Event.where(type: "google", last_google_hit: {
      "$gte" => start_time, "$lt" => end_time
    })
    types = hits.distinct(:url_type).sort

    slow = 100
    slow_hits = hits.where(my_ms: {"$gt" => slow}).asc(:my_ms)

    url_types = {}
    types.each do |type|
      criteria = hits.where(url_type: type)
      url_types[type][:count] = criteria.count
      url_types[type][:avg] = (criteria.only(&:my_ms).map(&:my_ms).sum.to_f / url_types[type][:count]).round
    end


    msg = "= Google activity for #{day}\n\n"
    msg += "Times are measured by Scout. External estimates add 60ms.\n\n"

    types.each do |type|
      count = fix url_types[type][:count], 7
      avg = fix url_types[type][:avg], 5
      est = fix "~#{url_types[type][:avg] + 60}", 6
      fixed_type = fix type, types.map(&:size).max
      msg += "/#{fixed_type} - #{count} hits (avg #{avg}, est #{est})"
    end

    msg += "\n\nSlow hits (>#{slow}ms as measured in Scout)\n\n"

    slow_hits.each do |hit|
      ms = fix hit.my_ms, 5
      link = "<a href=\"#{Environment.config[:hostname]}#{hit.url}>#{hit.url}</a>"
      msg += "#{ms}ms - #{link}"
    end

    msg
  end

  def fix(obj, width)
    obj = obj.to_s
    (" " * (width-obj.size)) + obj
  end

  def general_report(day)
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
namespace :analytics do

  desc "Daily report on various things."
  task daily: :environment do

    day = ENV['day'] || 1.day.ago.strftime("%Y-%m-%d")

    msg = ""
    msg += general_report day
    msg += google_report day
    puts msg
  end

  task google: :environment do
    begin
      day = ENV['day'] || 1.day.ago.strftime("%Y-%m-%d")
      msg = google_report day
      Admin.analytics "Google Report for #{day}", msg
    rescue Exception => ex
      report = Report.exception 'Analytics', "Exception preparing analytics:google", ex
      Admin.report report
      puts "Error sending analytics, emailed report."
    end
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

      url_types[type] = {}
      url_types[type][:count] = criteria.count
      url_types[type][:avg] = (criteria.only(&:my_ms).map(&:my_ms).sum.to_f / url_types[type][:count]).round
    end

    msg = "Crawling activity (avg measured by Scout, external est adds 60ms)\n\n"

    max_type = types.map(&:size).max
    max_count = url_types.values.map {|t| t[:count].to_s.size}.max
    max_avg = url_types.values.map {|t| t[:avg].to_s.size}.max

    types.each do |type|
      count = fix url_types[type][:count], max_count
      avg = fix url_types[type][:avg], max_avg
      est = fix "~#{url_types[type][:avg] + 60}", (max_avg + 1)
      fixed_type = fix type, max_type, :right
      msg += "  /#{fixed_type} - #{count} hits (avg #{avg}ms, est #{est}ms)\n"
    end

    msg += "\n\nSlow hits (>#{slow}ms as measured in Scout)\n\n"

    max_slow = slow_hits.only(&:my_ms).map {|h| h.my_ms.to_s.size}.max

    slow_hits.each do |hit|
      ms = fix hit.my_ms, max_slow
      msg += "  #{ms}ms - #{hit.url}\n"
    end

    msg
  end

  def fix(obj, width, side = :left)
    obj = obj.to_s
    spaces = width - obj.size
    spaces = 0 if spaces < 0
    space = " " * spaces

    if side == :left
      space + obj
    else
      obj + space
    end
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
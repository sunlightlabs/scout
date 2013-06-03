namespace :analytics do

  # desc "Daily report on various things."
  # task daily: :environment do

  #   day = ENV['day'] || 1.day.ago.strftime("%Y-%m-%d")

  #   msg = ""
  #   msg << general_report day
  #   msg << clicks_report day
  #   msg << google_report day
  #   puts msg
  # end

  task google: :environment do
    begin
      day = ENV['day'] || 1.day.ago.strftime("%Y-%m-%d")

      start_time = Time.zone.parse(day).midnight
      end_time = start_time + 1.day

      msg = google_report start_time, end_time
      Admin.analytics "google", "Google activity for #{day}", msg
    rescue Exception => ex
      report = Report.exception 'analytics:google', "Exception preparing analytics:google", ex
      Admin.report report
      puts "Error sending analytics, emailed report."
    end
  end

  task weekly: :environment do
    begin
      starting = ENV['starting'] || 7.day.ago.strftime("%Y-%m-%d")

      # the week in front of the day
      start_time = Time.zone.parse(starting).midnight
      end_time = start_time + 7.days

      service = ENV['service'] || "scout"

      msg = ""
      msg << general_report(start_time, end_time, service)
      msg << clicks_report(start_time, end_time, service)

      name = {"scout" => "Scout", "open_states" => "Open States"}[service]
      Admin.analytics "weekly_#{service}", "#{name} user activity for week of #{starting}", msg
    rescue Exception => ex
      report = Report.exception 'analytics:clicks', "Exception preparing analytics:clicks", ex
      Admin.report report
      puts "Error sending analytics, emailed report."
    end
  end




  def general_report(start_time, end_time, service)
    lookup_service = (service == "scout" ? nil : service)

    msg = ""


    total_users = User.where(service: lookup_service)
    # todo - expand this to accommodate unsubscribed users
    total_active_users = total_users.select {|u| u.interests.count > 0}
    total_interests = Interest.where(service: lookup_service)


    users = User.where(service: lookup_service, created_at: {
      "$gte" => start_time, "$lt" => end_time
    })

    interests = Interest.where(service: lookup_service, created_at: {
      "$gte" => start_time, "$lt" => end_time
    })

    removed = Event.where(type: "remove-alert", created_at: {
      "$gte" => start_time, "$lt" => end_time
    }).select {|e|
      (user = User.find(e.data['user_id'])) and
        (user.service == lookup_service)
    }

    unsubscribes = Event.where(type: "unsubscribe", "data.service" => lookup_service, created_at: {
      "$gte" => start_time, "$lt" => end_time
    })

    receipts = Receipt.where(mechanism: "email", user_service: lookup_service, created_at: {
      "$gte" => start_time, "$lt" => end_time
    })

    starting = start_time.strftime "%Y-%m-%d"
    ending = end_time.strftime "%Y-%m-%d"

    msg << "User activity from #{starting} to #{ending}:\n\n"

    msg << "  #{users.count} new users (#{total_users.count} total, #{total_active_users.size} active)\n"
    msg << "  #{interests.count} alerts created (#{total_interests.count} total)\n"
    msg << "  #{removed.size} alerts removed\n"
    msg << "  #{unsubscribes.count} full unsubscribes\n"
    msg << "  #{receipts.count} delivered emails\n"
    msg << "\n"

    msg
  end

  def clicks_report(start_time, end_time, service)
    lookup_service = (service == "scout" ? nil : service)
    clicks = Event.where(type: "email-click", service: lookup_service, created_at: {
      "$gte" => start_time, "$lt" => end_time
    })

    search_clicks = clicks.where(url_type: "item", interest_type: "search")
    search_types = search_clicks.distinct :subscription_type

    item_clicks = clicks.where(url_type: "item", interest_type: "item")
    item_types = item_clicks.distinct :subscription_type

    misc_clicks = clicks.where(url_type: nil)
    misc_urls = misc_clicks.distinct :to

    msg = ""

    msg << "Overall email clicks: #{clicks.count}\n\n"

    msg << "Clicks on new search results\n"
    if search_types.any?
      search_types.each do |type|
        count = search_clicks.where(subscription_type: type).count
        msg << "  #{count} - #{type}\n"
      end
    else
      msg << "  (no clicks on search results)\n"
    end
    msg << "\n"

    msg << "Clicks on bill- or legislator-specific activity\n"
    if item_types.any?
      item_types.each do |type|
        count = item_clicks.where(subscription_type: type).count
        msg << "  #{count} - #{type}\n"
      end
    else
      msg << "  (no clicks on item activity)\n"
    end
    msg << "\n"

    msg << "Clicks on URLs in email footers\n"
    if misc_urls.any?
      misc_urls.each do |url|
        count = misc_clicks.where(to: url).count
        msg << "  #{count} - #{url}\n"
      end
    else
      msg << "  (no clicks on footer URLs)\n"
    end
    msg << "\n"

    msg << "\n\n"

    msg
  end

  def google_report(start_time, end_time)
    hits = Event.where(type: "google", last_google_hit: {
      "$gte" => start_time, "$lt" => end_time
    })
    types = hits.distinct(:url_type).sort_by &:to_s

    slow = 200
    slow_hits = hits.where(my_ms: {"$gt" => slow}).asc(:my_ms)

    url_types = {}
    types.each do |type|
      criteria = hits.where(url_type: type)

      url_types[type] = {}
      url_types[type][:count] = criteria.count
      url_types[type][:avg] = (criteria.only(&:my_ms).map(&:my_ms).sum.to_f / url_types[type][:count]).round
    end

    msg = "Crawling activity (avg measured by Scout, external est adds 60ms)\n\n"

    max_type = types.map {|t| t.to_s.size}.max
    max_count = url_types.values.map {|t| t[:count].to_s.size}.max
    max_avg = url_types.values.map {|t| t[:avg].to_s.size}.max

    types.each do |type|
      count = fix url_types[type][:count], max_count
      avg = fix url_types[type][:avg], max_avg
      est = fix "~#{url_types[type][:avg] + 60}", (max_avg + 1)
      fixed_type = fix type, max_type, :right
      msg << "  /#{fixed_type} - #{count} hits (avg #{avg}ms, est #{est}ms)\n"
    end

    msg << "\n\nSlow hits (>#{slow}ms as measured in Scout)\n\n"

    max_slow = slow_hits.only(&:my_ms).map {|h| h.my_ms.to_s.size}.max

    slow_hits.each do |hit|
      ms = fix hit.my_ms, max_slow
      msg << "  #{ms}ms - #{URI.decode hit.url}\n"
    end

    msg
  end

  def rel(url)
    url.gsub /^#{Environment.config['hostname']}/, ''
  end

  def fixed(text)
    "<font size=\"-1\"><pre>#{text}</pre></font>"
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
end
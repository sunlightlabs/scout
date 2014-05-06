def topline
  msg = ""

  [nil, "open_states"].each do |service|
    msg << "[#{service || "scout"}]\n"
    msg << "\n"

    total_users = User.where(service: service).count
    active_users = User.where(service: service).select {|u| u.interests.count > 0}
    active_outside = active_users.reject {|u| u.email =~ /sunlightfoundation\.com/}

    msg << "Total users: #{total_users}\n"
    msg << "Active users (at least 1 alert): #{active_users.size}\n"
    msg << "Active outside users (at least 1 alert, excluding sunlightfoundation.com emails): #{active_outside.size}\n"
    msg << "\n"

    active_outside_alerts = active_outside.map {|u| u.interests.count}.sum
    msg << "Alerts by active outside users: #{active_outside_alerts}\n"
    msg << "\n"
    msg << "\n"
  end

  Admin.sensitive "Scout User Stats", msg
end

def activity_report(days)
  all_start = Time.zone.parse(days.first).midnight.strftime "%B %d, %Y"
  all_end = Time.zone.parse(days.last).midnight.strftime "%B %d, %Y"

  subject = "Activity from #{all_start} - #{all_end}"
  msg = ""

  days.each do |day|
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
    msg << "\n"

    users.each do |user|
      source = if user.source.is_a?(Hash)
        user.source['utm_source']
      else
        user.source
      end

      msg << "#{user.created_at.in_time_zone.strftime "%H:%M"} #{user.contact} - (#{user.interests.for_time(day, ending).count}) - #{source}\n"
    end

    msg << "\n\n"
  end

  Admin.sensitive subject, msg
end
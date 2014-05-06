# aggregated daily warnings - kept in the database through that day,
# then delivered and cleared.

namespace :warnings do

  desc "New users"
  task new_users: :environment do
    # send an email with any new users for the day.
    # break it up by service.

    body = ""

    day = ENV['day'] || 1.day.ago.strftime("%Y-%m-%d")
    ending = (Time.zone.parse(day) + 1.day).strftime "%Y-%m-%d"

    service = ENV['service'] || nil
    display_service = service || "scout"

    criteria = Event.where(type: "new-user", service: service).for_time(day, ending)

    if criteria.any?
      body << "[#{display_service}]"
      criteria.each do |event|
        body << "[#{event.created_at}] #{event.email}"
        body << " (unconfirmed)" if !event['confirmed']
        body << "\n"
      end

      Admin.message "[#{display_service}] New users for #{day}", body
    else
      puts "[#{display_service}] No new users for #{day} to deliver."
    end
  end

  desc "Backfill warnings"
  task backfills: :environment do
    # accumulate a full example of each, and a count of more

    header = ""

    backfills = []

    Event.where(type: "backfills").each do |event|
      backfills << {
        example: event.backfills.first,
        count: event.backfills.size,
        subscription_type: event.subscription_type,
        interest_in: event.interest_in
      }

      header << "[#{event.subscription_type}][#{event.interest_in}] #{event.backfills.size}"
      header << "\n"
    end

    if backfills.any?
      Admin.report Report.warning("Check", "#{backfills.size} sets of backfills today, not delivered.", header: header, backfills: backfills)
      Event.where(type: "backfills").delete_all
    else
      puts "No backfill warnings to deliver today."
    end
  end

  task courtlistener: :environment do
    # accumulate a full example of each, and a count of more
    warnings = []

    Event.where(type: "courtlistener").each do |event|
      warnings << {
        example: event.warnings.first,
        count: event.warnings.size,
        subscription_type: event.subscription_type,
        interest_in: event.interest_in
      }
    end

    if warnings.any?
      Admin.report Report.warning("Check", "#{warnings.size} CL warnings today, not delivered.", warnings: warnings)
      Event.where(type: "courtlistener").delete_all
    else
      puts "No CourtListener warnings to deliver today."
    end
  end

end
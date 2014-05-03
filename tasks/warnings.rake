# aggregated daily warnings - kept in the database through that day,
# then delivered and cleared.

namespace :warnings do

  desc "Backfill warnings"
  task backfills: :environment do
    # accumulate a full example of each, and a count of more
    backfills = []

    Event.where(type: "backfills").each do |event|
      backfills << {
        example: event.backfills.first,
        count: event.backfills.size,
        subscription_type: event.subscription_type,
        interest_in: event.interest_in
      }
    end

    if backfills.any?
      Admin.report Report.warning("Check", "#{backfills.size} backfills today, not delivered.", backfills: backfills)
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
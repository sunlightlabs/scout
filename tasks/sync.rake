namespace :sync do
  
  desc "Sync bills from Congress API"
  task federal_bills: :environment do
    options = {congress: ENV['congress']}

    start = Time.now

    total = 0
    page = 1
    while true # oh boy
      items = Subscriptions::Manager.sync "federal_bills", options.merge(page: page)
      
      unless items.is_a?(Array)
        Admin.report Report.failure("sync:federal_bills", "Error fetching page #{page}", {options: options, page: page, error: items})
        break
      end

      items.each {|item| Item.from_seen! item}

      total += items.size
      break if items.size < Subscriptions::Adapters::FederalBills::MAX_PER_PAGE
      break if (Time.now - start) > 60.minutes # emergency brake, I hate while-true's

      page += 1
    end

    Admin.report Report.success("sync:federal_bills", "Synced #{total} federal bills.", {duration: (Time.now - start), total: total})
  end
end
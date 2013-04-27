namespace :sync do
  
  desc "Sync bills from Congress API"
  task federal_bills: :environment do
    sync "federal_bills"
  end

  def sync(subscription_type)
    begin
      adapter = Subscription.adapter_for subscription_type
      start = Time.now

      # will mean something special to each adapter
      options = {since: ENV['since']}

      total = 0
      page = 1
      while true # oh boy
        items = Subscriptions::Manager.sync subscription_type, options.merge(page: page)
        
        unless items.is_a?(Array)
          Admin.report Report.failure("sync:#{subscription_type}", "Error fetching page #{page}", {options: options, page: page, error: items})
          break
        end

        items.each {|item| Item.from_seen! item}

        total += items.size
        break if items.size < adapter::MAX_PER_PAGE
        break if (Time.now - start) > 60.minutes # emergency brake, I hate while-true's

        page += 1
      end

      Admin.report Report.success("sync:#{subscription_type}", "Synced #{total} federal bills.", {duration: (Time.now - start), total: total, options: options, subscription_type: subscription_type})
    rescue Exception => ex
      Admin.report Report.exception("sync:#{subscription_type}", "Failed to sync bills, died at page #{page}", ex, {duration: (Time.now - start), options: options, subscription_type: subscription_type})
    end
  end
end
namespace :sync do
  
  [:state_bills, :federal_bills, :speeches, :regulations, :documents].each do |type|
    desc "Sync #{type}"
    task type => :environment do
      sync type.to_s
    end
  end

  def sync(subscription_type)
    begin
      adapter = Subscription.adapter_for subscription_type
      start = Time.now

      # will mean something special to each adapter
      options = {since: ENV['since']}

      total = 0
      page = ENV['start'] ? ENV['start'].to_i : 1

      while true # oh boy
        items = Subscriptions::Manager.sync subscription_type, options.merge(page: page)
        
        unless items.is_a?(Array)
          Admin.report Report.failure("sync:#{subscription_type}", "Error fetching page #{page}", {options: options, page: page})
          break
        end

        items.each {|item| Item.from_seen! item}

        total += items.size
        break if items.size < adapter::MAX_PER_PAGE
        
        # emergency brake, I hate while-true's
        if (Time.now - start) > 600.minutes
          puts "Emergency brake!"
          break
        end

        page += 1
      end

      Admin.report Report.success("sync:#{subscription_type}", "Synced #{total} #{subscription_type}.", {duration: (Time.now - start), total: total, options: options, subscription_type: subscription_type})
    rescue Exception => ex
      Admin.report Report.exception("sync:#{subscription_type}", "Failed to sync #{subscription_type}, died at page #{page}", ex, {duration: (Time.now - start), options: options, subscription_type: subscription_type})
    end
  end
end
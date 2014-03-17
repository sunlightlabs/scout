require 'active_support/core_ext/string/inflections'

Dir.glob(File.join(ENV.fetch('SCOUNT_ADAPTER_PATH', './subscriptions/adapters'), '*.rb')).each {|filename| load filename}

syncable = []
Subscriptions::Adapters.constants.each do |symbol|
  klass = Subscriptions::Adapters.const_get(symbol)
  if klass.const_defined?(:SYNCABLE) && klass::SYNCABLE
    syncable << symbol.to_s.underscore
  end
end

namespace :sync do

  syncable.each do |type|
    desc "Sync #{type}"
    task type => :environment do
      sync type
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

      bad_pages = []

      while true # oh boy
        items = Subscriptions::Manager.sync subscription_type, options.merge(page: page, start: start)

        unless items.is_a?(Array)
          bad_pages << page
          page += 1
          next
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

      if bad_pages.any?
        Admin.report Report.failure("sync:#{subscription_type}", "Error fetching pages", {options: options, bad_pages: bad_pages})
      end

      # not usually needed
      # Admin.report Report.success("sync:#{subscription_type}", "Synced #{total} #{subscription_type}.", {duration: (Time.now - start), total: total, options: options, subscription_type: subscription_type})
    rescue Exception => ex
      Admin.report Report.exception("sync:#{subscription_type}", "Failed to sync #{subscription_type}, died at page #{page}", ex, {duration: (Time.now - start), options: options, subscription_type: subscription_type})
    end
  end
end
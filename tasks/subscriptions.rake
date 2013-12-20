subscription_types = Dir.glob('subscriptions/adapters/*.rb').map do |file|
  File.basename file, File.extname(file)
end

namespace :subscriptions do

  # TODO: "everything" searches for citation searches should not add
  # subscription types that are not in the cite_types array in
  # config/environment.rb

  # for use in adding new subscription types to people's existing alerts.
  #
  # possible uses:
  #
  # add court opinion subscriptions to all existing Everything search interests
  #   rake subscriptions:generate subscription_type=court_opinions
  # add federal bill hearing subscriptions to all existing federal bill item interests
  #   rake subscriptions:generate subscription_type=federal_bills_hearings item_type=bill
  task generate: :environment do
    item_type = ENV['item_type']
    subscription_type = ENV['subscription_type']

    return unless subscription_type.present?

    if item_type.present?
      Interest.where(item_type: item_type).each do |interest|
        # force a new subscription to be returned even if the interest is a saved record
        Interest.subscription_for(interest, subscription_type, true).save!
      end
    else # assume this is a search type
      Interest.where(search_type: "all").each do |interest|
        # force a new subscription to be returned even if the interest is a saved record
        Interest.subscription_for(interest, subscription_type, true).save!
      end
    end
  end

  desc "Try to initialize any uninitialized subscriptions"
  task reinitialize: :environment do
    errors = []
    successes = []
    count = 0

    timer = (ENV['minutes'] || 25).to_i

    start = Time.now

    Subscription.uninitialized.each do |subscription|
      result = Subscriptions::Manager.initialize! subscription
      if result.nil? or result.is_a?(Hash)
        errors << result
      else
        successes << subscription
      end

      # no more than 25 (default) minutes' worth
      break if (Time.now - start) > timer.minutes
    end

    if errors.size > 0 # any? apparently returns false if the contents are just nils!
      Admin.report Report.warning(
        "Initialize", "#{errors.size} errors while re-initializing subscriptions, will try again later.",
        errors: errors,
        )
    end

    if successes.size > 0
      Admin.report Report.success "Initialize", "Successfully initialized #{successes.size} previously uninitialized subscriptions.", subscriptions: successes.map {|s| s.attributes.dup}
    else
      puts "Did not re-initialize any subscriptions."
    end
  end

  namespace :check do

    subscription_types.each do |subscription_type|

      desc "Check for new #{subscription_type} items for initialized subscriptions"
      task subscription_type.to_sym => :environment do
        begin
          rate_limit = ENV['rate_limit'].present? ? ENV['rate_limit'].to_f : 0.1

          count = 0
          errors = []
          start = Time.now

          puts "Clearing all caches for #{subscription_type}..."
          Subscriptions::Manager.uncache! subscription_type


          criteria = {subscription_type: subscription_type}

          if ENV['email']
            if user = User.where(email: ENV['email']).first
              criteria[:user_id] = user.id
            else
              puts "Not a valid email, ignoring."
              return
            end
          end

          Subscription.initialized.no_timeout.where(criteria).each do |subscription|
            if subscription.user.confirmed?

              result = Subscriptions::Manager.check!(subscription)
              count += 1

              if rate_limit > 0
                sleep rate_limit
                puts "sleeping for #{rate_limit}s"
              end

              if result.nil? or result.is_a?(Hash)
                errors << result
              end
            end
          end

          # feed errors are far too common to get this way - it's basically expected.
          # I can't even look at them to decide what makes sense. Users will need to observe
          # the behavior and preview of a feed and judge for themselves.
          if errors.any? and (subscription_type != "feed")
            Admin.report Report.warning(
              "check:#{subscription_type}", "#{errors.size} errors while checking #{subscription_type}, will check again next time.",
              errors: errors[0..20]
            )
          end

          Report.complete(
            "check:#{subscription_type}", "Completed checking #{count} #{subscription_type} subscriptions", elapsed_time: (Time.now - start)
          )

        rescue Exception => ex
          Admin.report Report.exception("check:#{subscription_type}", "Problem during 'rake subscriptions:check:#{subscription_type}'.", ex)
          puts "Error during subscription checking, emailed report."
        end
      end
    end

    desc "Check all subscription types right now (admin usage)"
    task :all => subscription_types.map {|type| "subscriptions:check:#{type}"} do
    end

  end
end

task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require './config/environment'
end

require 'rake/testtask'
load "./tasks/sync.rake"
load "./tasks/analytics.rake"

namespace :tests do
  Rake::TestTask.new(:all) do |t|
    t.libs << "test"
    t.test_files = FileList['test/**/*_test.rb']
  end

  ["functional", "helpers", "delivery", "unit"].each do |type|
    Rake::TestTask.new(type.to_sym) do |t|
      t.libs << "test"
      t.test_files = FileList["test/#{type}/*_test.rb"]
    end
  end
end

namespace :crontab do
  desc "Set the crontab in place for this environment"
  task :set => :environment do
    environment = ENV['environment']
    current_path = ENV['current_path']

    if environment.blank? or current_path.blank?
      Admin.message "No environment or current path given, emailing and exiting."
      next
    end

    if system("cat #{current_path}/config/cron/#{environment}/crontab | crontab")
      puts "Successfully overwrote crontab."
    else
      Admin.report Report.warning("Crontab", "Crontab overwriting failed on deploy.")
      puts "Unsuccessful in overwriting crontab, emailed report."
    end
  end

  desc "Disable/clear the crontab for this environment"
  task :disable => :environment do
    if system("echo | crontab")
      puts "Successfully disabled crontab."
    else
      Admin.message "Somehow failed at disabling crontab."
      puts "Unsuccessful (somehow) at disabling crontab, emailed report."
    end
  end
end

desc "Run through each model and create all indexes"
task :create_indexes => :environment do
  begin
    Mongoid.models.each do |model|
      model.create_indexes
      puts "Created indexes for #{model}"
    end

  rescue Exception => ex
    report = Report.exception 'Indexes', "Exception creating indexes", ex
    Admin.report report
    puts "Error creating indexes, emailed report."
  end
end

desc "Clear the database"
task :clear_data => :environment do
  models = Dir.glob('app/models/*.rb').map do |file|
    File.basename(file, File.extname(file)).camelize.constantize
  end

  models.each do |model|
    model.delete_all
    puts "Cleared model #{model}."
  end
end

subscription_types = Dir.glob('subscriptions/adapters/*.rb').map do |file|
  File.basename file, File.extname(file)
end

namespace :subscriptions do

  # don't run this from the command line - modify for individual tasks
  task :generate => :environment do
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
  task :reinitialize => :environment do
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
                puts "sleeping for #{rate_limit}"
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
              errors: errors[0..2],
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

namespace :deliver do

  desc "Custom delivery task"
  task :custom => :environment do
    interest_options = {
      "interest_type" => "search",
      "search_type" => {"$in" => ["all", "state_bills"]}
    }

    subject = "State bill alerts for 2013 so far"
    header = File.read("misc/header.htm")

    Deliveries::Manager.custom_email!(
      subject, header,
      interest_options
    )
  end

  desc "Deliveries for a single daily email digest"
  task :email_daily => :environment do
    delivery_options = {"mechanism" => "email", "email_frequency" => "daily"}

    if ENV['email']
      delivery_options["user_email"] = ENV['email'].strip
    end

    begin
      Deliveries::Manager.deliver! delivery_options
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:email_daily.", ex)
      puts "Error during delivery, emailed report."
    end
  end

  desc "Deliveries of emails for whenever, per-interest"
  task :email_immediate => :environment do
    delivery_options = {"mechanism" => "email", "email_frequency" => "immediate"}

    if ENV['email']
      delivery_options["user_email"] = ENV['email'].strip
    end

    begin
      Deliveries::Manager.deliver! delivery_options
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:email_immediate.", ex)
      puts "Error during delivery, emailed report."
    end
  end

  desc "Deliveries of SMSes for whenever, per-interest"
  task :sms => :environment do
    begin
      Deliveries::Manager.deliver! "mechanism" => "sms"
    rescue Exception => ex
      Admin.report Report.exception("Delivery", "Problem during deliver:sms.", ex)
      puts "Error during delivery, emailed report."
    end
  end
end

# some helpful test tasks to exercise emails and SMS

namespace :test do

  desc "Send a test email to the admin"
  task :email_admin => :environment do
    message = ENV['msg'] || "Test message. May you receive this in good health."
    Admin.message message
  end

  desc "Send two test reports"
  task :email_report => :environment do
    Admin.report Report.failure("Admin.report 1", "Testing regular failure reports.", {name: "test report"})
    Admin.report Report.exception("Admin.report 2", "Testing exception reports", Exception.new("WOW! OUCH!!"))
  end

  desc "Send a test SMS"
  task :sms => :environment do
    message = ENV['msg'] || "Test SMS. May you receive this in good health."
    number = ENV['number']

    unless number.present?
      puts "Include a 'number' parameter."
      return
    end

    ::SMS.deliver! "Test", number, message
  end

  desc "Creates an item subscription for a user"
  task follow_item: :environment do
    unless (item_id = ENV['item_id']).present? and (item_type = ENV['item_type']).present?
      puts "Provide an item_type and item_id"
      exit -1
    end

    unless user = User.where(email: (ENV['email'] || Environment.config['admin'].first)).first
      puts "Provide an email of a registered user."
      exit -1
    end

    interest = Interest.for_item user, item_id, item_type
    unless interest.new_record?
      puts "User already subscribed to that item."
      exit -1
    end

    adapter = if item_types[item_type] and item_types[item_type]['adapter']
      item_types[item_type]['adapter']
    else
      item_type.pluralize
    end

    unless item = Subscriptions::Manager.find(adapter, item_id)
      puts "Couldn't find remote information about the item."
      exit -1
    end

    interest.data = item.data

    if ENV['tags'].present?
      interest.tags = ENV['tags'].split ","
    end

    interest.save!

    puts "User subscribed to #{item_type} with ID: #{item_id}"
  end

  desc "Forces emails or SMSes to be sent for the first X results of every subscription a user has"
  task send_user: :environment do
    email = ENV['email'] || Environment.config['admin'].first
    phone = ENV['phone']

    max = (ENV['max'] || ENV['limit'] || 2).to_i
    only = (ENV['only'] || "").split(",")
    interest_in = (ENV['interest_in'] || "").split(",")

    citation = ENV['citation']

    function = (ENV['function'] || :check).to_sym

    mechanism = ENV['by'] || (phone.present? ? 'sms' : 'email')
    email_frequency = ENV['frequency'] || 'immediate'

    unless ['immediate', 'daily'].include?(email_frequency)
      puts "Use 'immediate' or 'daily' for a frequency."
      return
    end

    user = nil
    if phone.present?
      user = User.by_phone phone
    else
      user = User.where(:email => email).first
    end

    unless user
      puts "Can't find user by that email or phone."
      exit -1
    end

    puts "Clearing all deliveries for #{user.email || user.phone}"
    user.deliveries.delete_all

    user.interests.each do |interest|
      interest.subscriptions.each do |subscription|
        if only.any?
          next unless only.include?(subscription.subscription_type)
        end

        if citation
          next unless subscription.data['citation_id'] == citation
        end

        if interest_in.any?
          next unless interest_in.include?(subscription.interest_in)
        end

        puts "Searching for #{subscription.subscription_type} results for #{interest.in}..."
        items = Subscriptions::Manager.poll subscription, function, per_page: max
        if items.nil? or items.empty?
          puts "No results, nothing to deliver."
          next
        elsif items.is_a?(Hash)
          puts "ERROR searching:\n\n#{JSON.pretty_generate items}"
          next
        end

        followers = interest.followers

        items.first(max).each do |item|
          delivery = Deliveries::Manager.schedule_delivery! item, interest, subscription.subscription_type, nil, mechanism, email_frequency

          if ENV['include_followers'].present?
            followers.each do |follower|
              Deliveries::Manager.schedule_delivery! item, interest, subscription.subscription_type, follower, mechanism, email_frequency
            end
          end
        end
      end

    end

    Deliveries::Manager.deliver! "mechanism" => mechanism, "email_frequency" => email_frequency
  end

  desc "Deliver an individual delivery (use 'id' parameter)"
  task :delivery => :environment do
    id = ENV['id']
    if delivery = Delivery.find(id)
      Deliveries::Manager.deliver! '_id' => id, 'mechanism' => delivery.mechanism, 'email_frequency' => delivery.email_frequency
    else
      puts "Couldn't locate delivery by provided ID"
    end
  end

  namespace :remote do

    desc "Test remote subscription via SMS"
    task :subscribe => :environment do
      unless (phone = ENV['phone']).present?
        puts "Give a phone number with the 'phone' parameter."
      end
      item_type = ENV['item_type'] || 'bill'
      item_id = ENV['item_id'] || 'hr1234-112'
      hostname = ENV['host'] || Environment.config['hostname']

      url = "#{hostname}/remote/subscribe/sms"

      response = HTTParty.post url, {body: {phone: phone, interest_type: "item", item_type: item_type, item_id: item_id}}
      puts "Status: #{response.code}"
      if response.code == 200
        puts "Body: #{JSON.pretty_generate JSON.parse(response.body)}"
      else
        puts "Body: #{response.body}"
      end
    end

    desc "Test confirmation of remote account, via SMS"
    task confirm: :environment do
      unless (phone = ENV['phone']).present?
        puts "Give a phone number with the 'phone' parameter."
      end
      hostname = ENV['host'] || Environment.config['hostname']

      url = "#{hostname}/remote/subscribe/sms"
    end
  end

end

desc "Clear all cached content."
task clear_cache: :environment do
  Cache.delete_all
  puts "Cleared cache."
end


# depends on misc/usc.json having the structure of the US Code
# as output by the github.com/unitedstates/uscode project:
#
#   ./run structure --sections > usc.json

desc "Load in the structure of the US Code."
namespace :usc do
  task load: :environment do
    only = ENV['title'] || nil

    titles = MultiJson.load open("misc/usc.json")

    titles.each do |title|
      next if only and (title['number'].to_s != only.to_s)
      next if title['number']["a"] # skip appendices, too complicated

      title['subparts'].each do |section|
        puts "[#{section['citation']}] Processing..."

        cite = Citation.find_or_initialize_by citation_id: section['citation']
        cite.description = section['name']
        cite.citation_type = "usc"
        cite.usc['title'] = title['number']
        cite.usc['section'] = section['number']
        cite.usc['title_name'] = title['name']
        cite.save!
      end
    end
  end
end

# assumes usc already loaded, update the sitemap
# saves a static file, using the production URL
desc "Generate a sitemap."
task :sitemap => :environment do
  begin
    require 'big_sitemap'

    include Helpers::Routing

    counts = {
      tags: 0, cites: 0,
      pages: 2 # assume / and /about work
    }

    # options:
    #   debug: output extra info
    #   no_ping: don't ping google or bing
    #   only: only output certain types of info (usc, item types)

    debug = ENV['debug'] ? true : false
    ping = ENV['no_ping'] ? false : true
    only = ENV['only'].present? ? ENV['only'].split(',') : nil

    BigSitemap.generate(
      base_url: "https://scout.sunlightfoundation.com",
      document_root: "public/sitemap",
      url_path: "sitemap",
      ping_google: ping,
      ping_bing: ping) do

      # homepage! come back to me
      add "/", change_frequency: "daily"

      # about page, changes rarely
      add "/about", change_frequency: "monthly"

      # public tags
      Tag.where(public: true).each do |collection|
        counts[:tags] += 1
        path = collection_path collection.user, collection
        puts "[collection][#{collection.name}] Adding to sitemap..." if debug
        add path, change_frequency: "daily"
      end

      # map of US Code searches/landings
      if !only or (only and only.include?("usc"))
        Citation.where(citation_type: "usc").asc(:citation_id).each do |citation|
          counts[:cites] += 1
          standard = Search.cite_standard citation.attributes
          puts "[cite][#{standard}] Adding to sitemap..." if debug
          add "/search/all/#{URI.escape standard}", change_frequency: :daily
        end
      end

      # synced remote item landing pages
      frequencies = {
        bill: :weekly,
        state_bill: :weekly,
        speech: :monthly,
        regulation: :monthly,
        document: :monthly
      }

      item_types = frequencies.keys.sort
      if only #...
        item_types = item_types.select {|i| only.include? i.to_s}
      end

      item_types.each do |item_type|
        frequency = frequencies[item_type]

        counts[item_type] = 0
        Item.where(item_type: item_type.to_s).asc(:created_at).each do |item|
          counts[item_type] += 1
          url = landing_path item
          puts "[#{item_type}][#{item.item_id}] Adding to sitemap: #{url}" if debug
          add url, change_frequency: frequency
        end
      end

    end

    puts "Saved sitemaps."
  rescue Exception => ex
    report = Report.exception 'Sitemap', "Exception generating sitemap", ex
    Admin.report report
    puts "Error generating sitemap, emailed report."
  end
end

namespace :assets do

  desc "Synchronize assets to S3"
  task sync: :environment do

    begin
      # first, run through each asset and compress it using gzip
      Dir["public/assets/**/*.*"].each do |path|
        if File.extname(path) != ".gz"
          system "gzip -9 -c #{path} > #{path}.gz"
        end
      end

      # asset sync is configured to use the .gz version of a file if it exists,
      # and to upload it to the original non-.gz URL with the right headers
      AssetSync.sync
    rescue Exception => ex
      report = Report.exception 'Assets', "Exception compressing and syncing assets", ex
      Admin.report report
      puts "Error compressing and syncing assets, emailed report."
    end
  end
end

namespace :collection do

  # Rename a collection.
  #
  # * Find the Tag, capture its interests in an array.
  # * Change the Tag's name field.
  # * Take previously captured interests, replace old name
  #   with new one in "tags" field.
  task rename: :environment do

    unless (email = ENV['email']).present? and
      (collection_name = ENV['collection']).present? and
      (new_name = ENV['new_name']).present? and
      (user = User.where(email: email).first) and
      (collection = user.tags.where(name: collection_name).first)
      puts "Provide a valid 'email' and 'collection' name for that user."
      exit
    end

    interests = collection.interests.all.to_a
    collection.name = new_name.strip
    collection.save!
    interests.each do |interest|
      interest.tags.delete collection_name
      interest.tags << new_name
      interest.save!
    end

    puts "Renamed collection from \"#{collection_name}\" to \"#{new_name}\"."
  end

  # Copy one user's collection to another:
  #
  # * copy the Tag object itself
  #     - keep public/private status
  # * copy all interests who have that tag (collection)
  #     - *don't* copy over "notifications" or "tags" fields
  #       (or "_id", or "created_at", or "updated_at")
  #     - set "tags" field to [tag]
  #     - generate subscriptions for each interest
  #     - ensure each subscription is initialized
  task copy: :environment do

    unless (from_email = ENV['from']).present? and (to_email = ENV['to']).present? and
      (collection_name = ENV['collection']).present? and
      (from = User.where(email: from_email).first) and
      (to = User.where(email: to_email).first) and
      (collection = from.tags.where(name: collection_name).first)
      puts "Provide valid 'from' and 'to' user emails, and a 'collection' name."
      exit
    end

    # copy the collection
    attributes = collection.attributes.dup
    ["_id", "created_at", "updated_at"].each do |field|
      attributes.delete field
    end
    new_collection = to.tags.new attributes
    new_collection.save!
    puts "Saved collection \"#{collection_name}\"."

    # copy the collection's interests
    collection.interests.each do |interest|
      attributes = interest.attributes.dup
      ["tags", "notifications", "_id", "created_at", "updated_at"].each do |field|
        attributes.delete field
      end
      attributes["tags"] = [collection.name]
      new_interest = to.interests.new attributes
      new_interest.save!
      puts "Saved interest \"#{new_interest.in}\"."
    end

    puts "Did it work??"
  end
end

namespace :glossary do

  desc "Load glossary from the unitedstates/glossary project"
  task load: :environment do
    begin
      count = 0

      blacklist = %w{
        amendment
      }

      index_url = "https://api.github.com/repos/unitedstates/glossary/contents/definitions/congress?ref=gh-pages"
      puts "Downloading #{index_url}\n\n"
      definitions = Oj.load Subscriptions::Manager.download(index_url)

      # track current terms, and if any are no longer included upstream, delete them
      leftover_terms = Definition.distinct(:term).sort

      definitions.each do |file|
        path = file['path']
        term_url = "http://unitedstates.github.io/glossary/#{URI.encode path}"
        term = File.basename(path, ".json").downcase

        next if blacklist.include? term
        leftover_terms.delete term

        puts "[#{term}] Creating."
        details = Oj.load Subscriptions::Manager.download(term_url)

        definition = Definition.find_or_initialize_by term: term
        definition.attributes = details

        puts "\t#{definition.new_record? ? "Creating" : "Updating"}..."

        definition.save!
        count += 1
        sleep 0.2
      end

      leftover_terms.each do |term|
        puts "[#{term}] Axing, no longer in upstream glossary"
        Definition.where(term: term).delete
      end

      puts "Saved #{count} definitions, deleted #{leftover_terms.size} terms."

    rescue Exception => ex
      report = Report.exception 'Glossary', "Exception loading glossary.", ex
      Admin.report report
      puts "Error loading glossary, emailed report."
    end
  end
end

namespace :legislators do

  desc "Load current legislators"
  task load: :environment do
    begin
      json = Subscriptions::Manager.download Legislator.url_for_current
      results = Oj.load(json)['results']

      # wipe them all! restore them quickly! (only done once, at night)
      Legislator.delete_all

      results.each do |result|
        legislator = Legislator.new
        legislator.bioguide_id = result['bioguide_id']
        legislator.name = Legislator.name_for result
        legislator.title = result['title']
        legislator.save!
      end

      puts "Loaded #{Legislator.count} current legislators."

    rescue Exception => ex
      report = Report.exception 'Legislators', "Exception loading legislators.", ex
      Admin.report report
      puts "Error loading legislators, emailed report."
    end

  end
end
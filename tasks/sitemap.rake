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
      base_url: Environment.config['hostname'],
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
          url = item_path item
          puts "[#{item_type}][#{item.item_id}] Adding to sitemap: #{url}" if debug
          add url, change_frequency: frequency
        end
      end

    end

    puts "Saved sitemaps."
  rescue Exception => ex
    Admin.exception 'sitemap', ex
    puts "Error generating sitemap, emailed report."
  end
end

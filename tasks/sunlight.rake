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

namespace :glossary do

  desc "Load glossary from the unitedstates/glossary project"
  task load: :environment do
    begin
      count = 0

      blacklist = %w{
        amendment
      }

      rate_limit = ENV['rate_limit'].present? ? ENV['rate_limit'].to_f : 0.1

      index_url = "https://api.github.com/repos/unitedstates/glossary/contents/definitions/congress?ref=gh-pages"
      puts "Downloading #{index_url}\n\n"
      definitions = Oj.load Subscriptions::Manager.download(index_url)

      # track current terms, and if any are no longer included upstream, delete them
      leftover_terms = Definition.distinct(:term).sort

      definitions.each do |file|
        path = file['path']
        term_url = "http://theunitedstates.io/glossary/#{URI.encode path}"
        term = File.basename(path, ".json").downcase

        next if blacklist.include? term
        leftover_terms.delete term

        if rate_limit > 0
          puts "sleeping for #{rate_limit}s"
          sleep rate_limit
        end

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

namespace :agencies do
  desc "Load agency names/IDs from the Federal Register"
  task load: :environment do

    begin
      json = Subscriptions::Manager.download Agency.agencies_url
      results = Oj.load json

      # wipe them all! restore them quickly! (only done once, at night)
      Agency.delete_all

      results.each do |result|
        agency = Agency.new
        agency.attributes = Agency.agency_for result
        agency.save!
      end

      puts "Loaded #{Agency.count} current federal agencies."

    rescue Exception => ex
      report = Report.exception 'Agencies', "Exception loading agencies.", ex
      Admin.report report
      puts "Error loading agencies, emailed report."
    end

  end
end

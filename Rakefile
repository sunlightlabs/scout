task default: 'tests:all'

task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require './config/environment'
end

require 'rake/testtask'

Dir.glob('tasks/*.rake').each{|filename| load filename}

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

desc "Clear all cached content."
task clear_cache: :environment do
  Cache.delete_all
  puts "Cleared cache."
end

task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'config/environment'
end

desc "Run through each model and create all indexes" 
task :create_indexes => :environment do
  begin
    models = Dir.glob('models/*.rb').map do |file|
      File.basename(file, File.extname(file)).camelize.constantize
    end
    
    models.each do |model| 
      if model.respond_to? :create_indexes
        model.create_indexes 
        puts "Created indexes for #{model}"
      else
        puts "Skipping #{model}, not a Mongoid model"
      end
    end
  rescue Exception => ex
    # email "Exception creating indexes, message and backtrace attached", {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}
    puts "Error creating indexes, emailed report."
  end
end


# subscription management tasks

namespace :subscriptions do
  
  desc "Poll for new items for every active, initialized subscription"
  task :poll do
    
    
    
  end

end
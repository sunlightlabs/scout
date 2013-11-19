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

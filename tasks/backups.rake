require 'aws-sdk'

namespace :backups do

  desc "Monitor S3 backup location"
  task check: :environment do
    begin

      if ENV['day']
        day = Time.zone.parse(ENV['day'])
      else
        day = Time.zone.now
      end
      day = day.strftime("%Y%m%d")


      s3 = AWS::S3.new(
        access_key_id: Environment.config['backups']['access_key'],
        secret_access_key: Environment.config['backups']['secret_key']
      )
      bucket_name = Environment.config['backups']['bucket']
      bucket = s3.buckets[bucket_name]
      path = Environment.config['backups']['path']
      dir = bucket.objects.with_prefix(path)

      key = "#{path}/#{day}.tgz"

      puts "Hunting for s3://#{bucket_name}/#{key} ..."

      found = dir.find do |object|
        object.key == key
      end

      if found.nil?
        Admin.message "WARNING: No backup found for #{day}."
      elsif found.content_length == 0
        Admin.message "WARNING: 0-byte backup found for #{day}."
      else
        puts "\nNo problem, backup is fine: #{key}, #{found.content_length} bytes."
      end

    rescue Exception => ex
      Admin.exception "backups:check", ex
      puts "Error monitoring S3 backups, emailed report."
    end
  end
end

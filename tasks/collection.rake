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

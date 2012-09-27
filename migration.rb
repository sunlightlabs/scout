
# 1) reload prod db on dev

# 2) update all citation search interests
Interest.where(interest_type: "search", "data.citation_type" => {"$exists" => true}).each do |interest|
  interest_in = interest['original_in']

  # get rid of the citation garbage and original_in
  interest.in = interest_in
  interest.data.delete "citation_type"
  interest.data.delete "citation_id"
  interest.data['query'] = interest_in
  interest.save!

  
  # regenerate subscriptions

  interest.subscriptions.destroy_all
  interest.seen_items.destroy_all
  interest.deliveries.delete_all

  interest.subscriptions = Interest.subscriptions_for interest, true
  interest.create_subscriptions
end


# 3) get rid of more old columns

db.interests.update({}, {"$unset": {"extra": 1}}, false, true)
db.interests.update({}, {"$unset": {"original_in": 1}}, false, true)
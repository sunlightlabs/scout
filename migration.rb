
# 1) reload prod db on dev

# 2) update all citation search interests
Interest.where(interest_type: "search").each do |interest|
  
  if interest['original_in'].present?
    interest.in = interest['original_in']
  end
  interest.query_type = interest.data['query_type']
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
db.interests.update({}, {"$unset": {"data.query_type": 1}}, false, true)
db.interests.update({}, {"$unset": {"data.query": 1}}, false, true)
db.interests.update({}, {"$unset": {"data.citation_id": 1}}, false, true)
db.interests.update({}, {"$unset": {"data.citation_type": 1}}, false, true)
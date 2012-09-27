
# 1) reload prod db on dev

# 2) update all citation search interests
Interest.where(interest_type: "search", data.citation_type" => {"$exists" => true}).each do |i|
  interest_in = i['original_in']

  # get rid of the citation garbage and original_in
  i.in = interest_in
  i.data.delete "citation_type"
  i.data.delete "citation_id"
  i.data['query'] = interest_in
  i.save!

  # regenerate subscriptions
  i.subscriptions.delete_all
  Interest.subscriptions_for(i, true).each {|s| s.save!}
end


# 3) get rid of more old columns

db.interests.update({}, {"$unset": {"extra": 1}}, false, true)
db.interests.update({}, {"$unset": {"original_in": 1}}, false, true)
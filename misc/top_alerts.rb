# scratch code used to calculate top searches and bills

is = Interest.where(interest_type: "search").select do |i|
  i.user.service.nil? and (i.user.email !~ /sunlightfoundation/i)
end; is.size

is = Interest.where(interest_type: "item", item_type: "bill").select do |i|
  i.user.service.nil? and (i.user.email !~ /sunlightfoundation/i)
end; is.size


terms = {}
is.each do |interest|
  terms[interest.in] ||= 0
  terms[interest.in] += 1
end; is.size

sorted = terms.keys.sort_by {|key| terms[key]}
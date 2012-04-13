# search results

get '/search/:subscriptions/?:query?' do
  query = params[:query] ? params[:query].gsub("\"", "") : nil

  subscriptions = params[:subscriptions].split(",").map do |slug|
    subscription_type, index = slug.split "-"
    next unless search_adapters.keys.include?(subscription_type)

    data = (params[slug] || {}).merge(:query => query)

    Subscription.new(
      :interest_in => query,
      :subscription_type => subscription_type,
      :data => data,
      :slug => slug
    )
  end.compact

  halt 404 and return unless subscriptions.any?

  erb :"search/search", :layout => !pjax?, :locals => {
    :subscriptions => subscriptions,
    :query => query
  }
end

get '/fetch/search/:subscription_type/?:query?' do
  query = params[:query] ? params[:query].strip : nil
  subscription_type = params[:subscription_type]

  data = (params[subscription_type] || {}).merge(:query => query)

  subscription = Subscription.new(
    :subscription_type => subscription_type,
    :interest_in => query,
    :data => data
  )

  page = params[:page].present? ? params[:page].to_i : 1
  per_page = params[:per_page].present? ? params[:per_page].to_i : nil

  # perform the remote search, pass along pagination preferences
  results = subscription.search :page => page, :per_page => per_page
    
  # if results is nil, it usually indicates an error in one of the remote services
  if results.nil?
    puts "[#{subscription_type}][#{interest_in}][search] ERROR while loading this"
  end
  
  html = erb :"search/items", :layout => false, :locals => {
    :items => results, 
    :subscription => subscription,
    :query => query,
    :sole => (per_page > 5)
  }

  headers["Content-Type"] = "application/json"
  
  count = results ? results.size : -1
  {
    :count => count,
    :html => html,

    # TODO: don't return this at all unless it's in developer mode (a non-system API key in use)
    :search_url => (count > 0 ? results.first.search_url : nil)
  }.to_json
end

post '/subscriptions' do
  requires_login

  query = params[:query] ? params[:query].strip : nil
  subscription_type = params[:subscription_type]

  interest = current_user.interests.find_or_initialize_by(
    :in => query, 
    :interest_type => "search",
    :data => {
      'query' => query
    }
  )
  
  data = (params[subscription_type] || {}).merge(:query => query)

  subscription = current_user.subscriptions.find_or_initialize_by(
    :interest_in => query, 
    :subscription_type => subscription_type,
    :data => data
  )

  if params[:subscription_data]
    subscription.data = params[:subscription_data]
  end
  
  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscription.valid?
    interest.save!
    subscription[:interest_id] = interest.id
    subscription.save!
    
    halt 200
  else
    halt 500
  end
end

# delete the subscription, and, if it's the last subscription under the interest, delete the interest
# delete '/subscription/:id' do
#   requires_login

#   if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
#     halt 404 unless interest = Interest.where(:user_id => current_user.id, :_id => subscription.interest_id).first

#     deleted_interest = false

#     if interest.subscriptions.count == 1
#       interest.destroy
#       deleted_interest = true
#     end

#     subscription.destroy

#     pane = deleted_interest ? nil : partial("partials/interest", :engine => "erb", :locals => {:interest => interest})

#     headers["Content-Type"] = "application/json"
#     {
#       :deleted_interest => deleted_interest,
#       :interest_id => interest.id.to_s,
#       :pane => pane
#     }.to_json
#   else
#     halt 404
#   end
# end

delete '/interest/:id' do
  requires_login
  
  if interest = current_user.interests.find(params[:id])
    interest.destroy
    halt 200
  else
    halt 404
  end
end

# post '/item/:item_id/follow' do
#   requires_login

#   interest_type = params[:interest_type]
#   item_id = URI.decode params[:item_id] # can possibly have spaces, decode first
  
#   unless item = Subscriptions::Manager.find(interest_data[interest_type][:adapter], item_id)
#     halt 404 and return
#   end

#   interest = current_user.interests.new :interest_type => interest_type, :in => item_id, :data => item.data

#   subscriptions = interest_data[interest_type][:subscriptions].keys.map do |subscription_type|
#     current_user.subscriptions.new :interest_in => item_id, :subscription_type => subscription_type
#   end

#   if interest.valid? and (subscriptions.reject {|s| s.valid?}.empty?)
#     interest.save!
#     subscriptions.each do |subscription|
#       subscription[:interest_id] = interest.id
#       subscription.save!
#     end

#     headers["Content-Type"] = "application/json"
#     {
#       :interest_id => interest.id.to_s,
#       :pane => partial("partials/interest", :engine => "erb", :locals => {:interest => interest})
#     }.to_json
#   else
#     halt 500
#   end
# end


# delete '/item/:item_id/unfollow' do
#   requires_login

#   unless interest = current_user.interests.where(:_id => BSON::ObjectId(params[:interest_id].strip)).first
#     halt 404 and return
#   end

#   subscriptions = interest.subscriptions.to_a
    
#   interest.destroy
#   subscriptions.each do |subscription| 
#     subscription.destroy
#   end
  
#   halt 200
# end
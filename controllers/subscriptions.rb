# search results

get '/search/:subscription_types/?:query?' do
  query = params[:query] ? params[:query].gsub("\"", "") : nil

  types = params[:subscription_types].split(",").select {|type| search_adapters.keys.include?(type)}
  subscriptions = types.map {|type| subscription_for type}

  halt 404 and return unless subscriptions.any?

  erb :"search/search", :layout => !pjax?, :locals => {
    :subscriptions => subscriptions, # deprecated
    :subscription => subscriptions.first,
    :query => query
  }
end

get '/fetch/search/:subscription_type/?:query?' do
  query = params[:query] ? params[:query].strip : nil
  subscription_type = params[:subscription_type]

  subscription = subscription_for subscription_type

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
    :html => html
  }.to_json
end

post '/subscriptions' do
  requires_login

  query = params[:query] ? params[:query].strip : nil
  subscription_type = params[:subscription_type]

  subscription = subscription_for subscription_type

  halt 200 and return unless subscription.new_record?

  interest = current_user.interests.new(
    :in => query, 
    :interest_type => "search",
    :data => {'query' => query}
  )
  
  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscription.valid?
    interest.save!
    subscription.interest = interest
    subscription.save!
    
    halt 200
  else
    halt 500
  end
end

# delete the subscription, and, if it's the last subscription under the interest, delete the interest
delete '/subscriptions' do
  requires_login

  query = params[:query] ? params[:query].strip : nil
  subscription_type = params[:subscription_type]

  subscription = subscription_for subscription_type
  halt 404 and return false if subscription.new_record?

  subscription.destroy

  interest = Interest.find subscription.interest_id
  interest.destroy if interest.subscriptions.empty?

  halt 200
end

delete '/interest/:id' do
  requires_login
  
  if interest = current_user.interests.find(params[:id])
    interest.destroy
    halt 200
  else
    halt 404
  end
end

post '/item/:interest_type/:item_id/follow' do
  requires_login

  interest_type = params[:interest_type]
  item_id = URI.decode params[:item_id] # can possibly have spaces, decode first
  
  unless item = Subscriptions::Manager.find(interest_data[interest_type][:adapter], item_id)
    halt 404 and return
  end

  interest = current_user.interests.new(
    :interest_type => interest_type, 
    :in => item_id, 
    :data => item.data
  )

  subscriptions = interest_data[interest_type][:subscriptions].keys.map do |subscription_type|
    current_user.subscriptions.new :interest_in => item_id, :subscription_type => subscription_type
  end

  if interest.valid? and (subscriptions.reject {|s| s.valid?}.empty?)
    interest.save!
    subscriptions.each do |subscription|
      subscription.interest = interest
      subscription.save!
    end

    halt 200
  else
    halt 500
  end
end


delete '/item/:interest_type/:item_id/unfollow' do
  requires_login

  unless interest = current_user.interests.where(:in => params[:item_id], :interest_type => params[:interest_type]).first
    halt 404 and return
  end

  subscriptions = interest.subscriptions.to_a
    
  interest.destroy
  subscriptions.each do |subscription| 
    subscription.destroy
  end
  
  halt 200
end


put '/interest/:id' do
  requires_login

  unless interest = current_user.interests.find(params[:id])
    halt 404 and return false
  end

  interest.notifications = params[:interest]['notifications']

  if interest.save
    halt 200
  else
    halt 500
  end
end

helpers do

  # initializes a subscription of the given type, or, 
  # if the user is logged in, finds any existing one
  def subscription_for(subscription_type)
    query = params[:query] ? params[:query].gsub("\"", "") : nil

    data = (params[subscription_type] || {}).merge('query' => query)

    criteria = {
      :interest_in => query,
      :subscription_type => subscription_type
    }

    # for lookups, we need to use dot notation, not pass in the data hash directly
    find_criteria = criteria.dup
    data.each do |key, value|
      find_criteria["data.#{key}"] = value
    end

    new_criteria = criteria.merge :data => data

    if logged_in?
      # can't use #find_or_initialize_by because of the dot notation
      current_user.subscriptions.where(find_criteria).first || current_user.subscriptions.new(new_criteria)
    else
      Subscription.new new_criteria
    end
  end

end
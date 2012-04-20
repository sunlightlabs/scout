# search results

get '/search/:subscription_type/?:query?' do
  query = stripped_query

  if params[:subscription_type] == "all"
    types = ["federal_bills", "speeches", "state_bills", "regulations"]
  else
    types = [params[:subscription_type]]
  end

  types = types.select {|type| search_adapters.keys.include?(type)}
  halt 404 and return unless types.any?

  subscriptions = types.map {|type| subscription_for type}
  halt 404 and return unless subscriptions.any?

  if subscriptions.size > 1
    erb :"search/search_all", :layout => !pjax?, :locals => {
      :subscriptions => subscriptions,
      :following => !subscriptions.first.new_record?,
      :query => query
    }
  else
    erb :"search/search", :layout => !pjax?, :locals => {
      :subscriptions => subscriptions, # deprecated
      :subscription => subscriptions.first,
      :query => query
    }
  end
end

get '/fetch/search/:subscription_type/?:query?' do
  query = stripped_query
  subscription_type = params[:subscription_type]

  subscription = subscription_for subscription_type

  page = params[:page].present? ? params[:page].to_i : 1
  per_page = params[:per_page].present? ? params[:per_page].to_i : nil

  # perform the remote search, pass along pagination preferences
  results = subscription.search :page => page, :per_page => per_page
    
  # if results is nil, it usually indicates an error in one of the remote services
  if results.nil?
    puts "[#{subscription_type}][#{query}][search] ERROR while loading this"
  end
  
  erb :"search/items", :layout => false, :locals => {
    :items => results, 
    :subscription => subscription,
    :query => query,
    :sole => (per_page > 5)
  }
end

post '/subscriptions' do
  requires_login

  query = stripped_query

  if params[:subscription_type] == "all"
    subscriptions = search_adapters.keys.map do |subscription_type|
      subscription_for subscription_type
    end
  else
    subscriptions = [subscription_for(params[:subscription_type])]
  end

  interest = current_user.interests.new(
    :in => query, 
    :interest_type => "search",
    :data => {'query' => query}
  )

  halt 200 and return unless subscriptions.select {|s| s.new_record?}.any?
  
  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscriptions.reject {|s| s.valid?}.empty?
    interest.save! if interest.new_record?
    subscriptions.each do |subscription|
      subscription.interest = interest
      subscription.save!
    end
    
    halt 200
  else
    headers["Content-Type"] = "application/json"
    status 500
    {
      :errors => {
        :interest => interest.errors.full_messages,
        :subscription => subscription.errors.full_messages
      }
    }.to_json
  end
end

# delete the subscription, and, if it's the last subscription under the interest, delete the interest
delete '/subscriptions' do
  requires_login

  query = stripped_query
  subscription_type = params[:subscription_type]

  if subscription_type == "all"
    types = ["federal_bills", "speeches", "state_bills", "regulations"]
    subscriptions = types.map {|type| subscription_for type}
  else
    subscription = subscription_for subscription_type
    halt 404 and return false if subscription.new_record?
    subscriptions = [subscription]
  end

  subscriptions = subscriptions.reject &:new_record?
  subscriptions.each &:destroy

  interest = Interest.find subscriptions.first.interest_id
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
    query = stripped_query

    data = params[subscription_type] || {}
    
    if query
      data = data.merge('query' => query)
    end

    criteria = {
      :interest_in => query,
      :subscription_type => subscription_type,
      :data => data
    }

    if logged_in?
      # can't use #find_or_initialize_by because of the dot notation
      current_user.subscriptions.where(criteria).first || current_user.subscriptions.new(criteria)
    else
      Subscription.new criteria
    end
  end

  def stripped_query
    params[:query] ? URI.decode(params[:query].strip.gsub("\"", "")) : nil
  end
end
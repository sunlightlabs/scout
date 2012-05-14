# search results

get '/search/:subscription_type/?:query?' do
  query = stripped_query

  if params[:subscription_type] == "all"

    # hardcoded to preserve order...need a better solution
    types = search_subscription_types

  else
    types = [params[:subscription_type]]
  end

  types = types.select {|type| search_adapters.keys.include?(type)}
  halt 404 and return unless types.any?

  subscriptions = types.map {|type| subscription_for query, type}
  halt 404 and return unless subscriptions.any?

  # could be nil if user is not logged in
  interest = search_interest_for query

  erb :"search/search", :layout => !pjax?, :locals => {
    :subscriptions => subscriptions,
    :subscription => (subscriptions.size == 1 ? subscriptions.first : nil),
    :subscription_type => params[:subscription_type],
    :search_types => search_subscription_types,
    :interest => interest,
    :query => query
  }
end

get '/fetch/search/:subscription_type/?:query?' do
  query = stripped_query
  subscription_type = params[:subscription_type]

  subscription = subscription_for query, subscription_type

  page = params[:page].present? ? params[:page].to_i : 1
  per_page = params[:per_page].present? ? params[:per_page].to_i : nil

  # perform the remote search, pass along pagination preferences
  results = subscription.search :page => page, :per_page => per_page
    
  # if results is nil, it usually indicates an error in one of the remote services
  if results.nil?
    puts "[#{subscription_type}][#{query}][search] ERROR while loading this"
  end
  
  items = erb :"search/items", :layout => false, :locals => {
    :items => results, 
    :subscription => subscription,
    :query => query,
    :sole => (per_page > 5),
    :page => page
  }

  headers["Content-Type"] = "application/json"
  {
    :html => items,
    :count => (results ? results.size : -1),
    :sole => (per_page > 5),
    :page => page
  }.to_json
end

post '/subscriptions' do
  requires_login

  query = stripped_query

  if params[:subscription_type] == "all"
    subscriptions = search_adapters.keys.map do |subscription_type|
      subscription_for query, subscription_type
    end
  else
    subscriptions = [subscription_for(query, params[:subscription_type])]
  end

  interest = search_interest_for query

  halt 200 and return unless subscriptions.any? {|s| s.new_record?}
  
  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscriptions.reject {|s| s.valid?}.empty?
    interest.save! if interest.new_record?
    subscriptions.each do |subscription|
      subscription.interest = interest
      subscription.save!
    end

    subscription = subscriptions.size == 1 ? subscriptions.first : nil
    interest_pane = partial "search/subscriptions", :engine => :erb, :locals => {:interest => interest, :current_subscription => subscription}
    json 200, {
      :interest_pane => interest_pane
    }
  else
    json 500, {
      :errors => {
        :interest => interest.errors.full_messages,
        :subscription => subscription.errors.full_messages
      }
    }
  end
end

# delete the subscription, and, if it's the last subscription under the interest, delete the interest
delete '/subscriptions' do
  requires_login

  query = stripped_query
  subscription_type = params[:subscription_type]

  if subscription_type == "all"
    types = ["federal_bills", "speeches", "state_bills", "regulations"]
    subscriptions = types.map {|type| subscription_for query, type}
  else
    subscription = subscription_for query, subscription_type
    halt 404 and return false if subscription.new_record?
    subscriptions = [subscription]
  end

  interest = search_interest_for query

  subscriptions = subscriptions.reject &:new_record?
  subscriptions.each &:destroy

  if interest.subscriptions.count == 0
    interest.destroy
    interest_pane = nil
  else
    interest_pane = partial "search/subscriptions", :engine => :erb, :locals => {:interest => interest, :current_subscription => nil}
  end

  json 200, {
    :interest_pane => interest_pane
  }
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
  def subscription_for(query, subscription_type)
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
      current_user.subscriptions.find_or_initialize_by criteria
    else
      Subscription.new criteria
    end
  end

  def search_interest_for(query)
    if logged_in?
      current_user.interests.find_or_initialize_by(
        :in => query, 
        :interest_type => "search",
        :data => {'query' => query}
      )
    end
  end

  def stripped_query
    params[:query] ? URI.decode(params[:query].strip.gsub("\"", "")) : nil
  end

  # search_adapter.keys, but in order
  def search_subscription_types
    ["federal_bills", "speeches", "state_bills", "regulations"]
  end
end
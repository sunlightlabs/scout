# search results

get '/search/:subscription_type/?:query?' do
  halt 404 and return unless (search_adapters.keys + ["all"]).include?(params[:subscription_type])

  query = stripped_query

  interest = search_interest_for query, params[:subscription_type]
  subscriptions = search_subscriptions_for interest

  erb :"search/search", :layout => !pjax?, :locals => {
    :interest => interest,

    :subscriptions => subscriptions,
    :subscription => (subscriptions.size == 1 ? subscriptions.first : nil),

    :search_types => search_subscription_types, # ditch this, ugh

    :related_interests => related_interests(query),
    :query => query
  }
end

get '/fetch/search/:subscription_type/?:query?' do
  query = stripped_query
  subscription_type = params[:subscription_type]

  interest = search_interest_for query, params[:subscription_type]
  subscription = search_subscriptions_for(interest).first
  
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
    :sole => (per_page.to_i > 5),
    :page => page
  }

  headers["Content-Type"] = "application/json"
  {
    :html => items,
    :count => (results ? results.size : -1),
    :sole => (per_page.to_i > 5),
    :page => page
  }.to_json
end

post '/interests/search' do
  requires_login

  query = stripped_query
  interest = search_interest_for query, params[:search_type]

  halt 200 and return unless interest.new_record?

  subscriptions = search_subscriptions_for interest
  
  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscriptions.reject {|s| s.valid?}.empty?
    interest.save!
    subscriptions.each do |subscription|
      subscription.interest = interest
      subscription.save!
    end

    interest_pane = partial "search/related_interests", :engine => :erb, :locals => {:related_interests => related_interests(query), :current_interest => interest}
    json 200, {
      :interest_pane => interest_pane
    }
  else
    json 500, {
      :errors => {
        :interest => interest.errors.full_messages,
        :subscription => subscriptions.first.errors.full_messages
      }
    }
  end
end

# delete the subscription, and, if it's the last subscription under the interest, delete the interest
delete '/interests/search' do
  requires_login

  query = stripped_query
  search_type = params[:search_type]

  interest = search_interest_for query, params[:search_type]
  halt 404 and return false if interest.new_record?
  
  interest.destroy

  interest_pane = partial "search/related_interests", :engine => :erb, :locals => {
    :related_interests => related_interests(query), 
    :current_interest => nil
  }

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
  
  unless item = Subscriptions::Manager.find(interest_data[interest_type]['adapter'], item_id)
    halt 404 and return
  end

  interest = current_user.interests.new(
    :interest_type => interest_type, 
    :in => item_id, 
    :data => item.data
  )

  subscriptions = interest_data[interest_type]['subscriptions'].keys.map do |subscription_type|
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

  if params[:interest]['notifications']
    interest.notifications = params[:interest]['notifications']
  end

  if params[:interest]['tags']
    interest.new_tags = params[:interest]['tags']
  end

  if interest.save
    pane = partial "account/tags", :engine => :erb, :locals => {:tags => current_user.interests.distinct(:tags)}
    json 200, {
      :tags => interest.tags,
      :notifications => interest.notifications,
      :tags_pane => pane
    }
  else
    halt 500
  end
end

helpers do

  # # initializes a subscription of the given type, or, 
  # # if the user is logged in, finds any existing one
  # def search_subscription_for(query, subscription_type)
  #   data = params[subscription_type] || {}

  #   if query
  #     data['query'] = query
  #   end

  #   Subscription.for current_user, subscription_type, query, data
  # end

  # subscription_type can be "all"
  def search_interest_for(query, search_type)
    data = params[search_type] || {}

    if query
      data['query'] = query
    end

    Interest.search_for current_user, search_type, query, data
  end

  # assumes that oneself is a new record, and a search interest
  def search_subscriptions_for(interest)
    if interest.new_record?
      types = (interest.search_type == "all") ? search_adapters.keys : [interest.search_type]
      types.map do |subscription_type|
        interest.subscriptions.new(
          :interest_in => interest.in, :subscription_type => subscription_type,
          :data => interest.data, # will only be relevant for single-search interests,
          :user => current_user
        )
      end
    else
      interest.subscriptions
    end
  end

  def related_interests(query)
    if logged_in?
      current_user.interests.where(
        :in => query, 
        :interest_type => "search"
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
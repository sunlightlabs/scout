# landing pages

get "/item/:item_type/:item_id" do
  interest = item_interest_for params[:item_id], params[:item_type]

  types = item_types[params[:item_type]]['subscriptions'] || []
  subscriptions = types.map do |subscription_type|
    item_subscription_for interest, subscription_type
  end

  erb :show, :layout => !pjax?, :locals => {
    :interest => interest,
    :subscriptions => subscriptions,
    :item_type => params[:item_type],
    :item_id => params[:item_id]
  }
end

get "/fetch/item/:item_type/:item_id" do
  item_type = params[:item_type].strip
  item_id = params[:item_id].strip
  subscription_type = item_types[item_type]['adapter']

  unless item = Subscriptions::Manager.find(subscription_type, item_id)
    halt 404 and return
  end

  interest = item_interest_for item_id, item_type

  erb :"subscriptions/#{subscription_type}/_show", :layout => false, :locals => {
    :item => item,
    :interest => interest,
    :item_type => item_type
  }
end

get "/fetch/item/:item_type/:item_id/:subscription_type" do
  halt 404 unless (type = item_types[params[:item_type]]) and (type['subscriptions'].include?(params[:subscription_type]))

  interest = item_interest_for params[:item_id], params[:item_type]
  subscription = item_subscription_for interest, params[:subscription_type]

  items = subscription.search

  partial "show_results", :engine => :erb, :locals => {
    :interest => interest,
    :subscription => subscription,
    :items => items
  }
end

post '/item/:item_type/:item_id/follow' do
  requires_login

  item_type = params[:item_type]
  item_id = URI.decode params[:item_id] # can possibly have spaces, decode first
  
  unless item = Subscriptions::Manager.find(item_types[item_type]['adapter'], item_id)
    halt 404 and return
  end

  interest = current_user.interests.new(
    :interest_type => item_type, 
    :in => item_id, 
    :data => item.data
  )

  subscriptions = item_types[item_type]['subscriptions'].map do |subscription_type|
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


delete '/item/:item_type/:item_id/unfollow' do
  requires_login

  unless interest = current_user.interests.where(:in => params[:item_id], :interest_type => params[:item_type]).first
    halt 404 and return
  end

  subscriptions = interest.subscriptions.to_a
    
  interest.destroy
  subscriptions.each do |subscription| 
    subscription.destroy
  end
  
  halt 200
end


helpers do
  def item_interest_for(item_id, item_type)
    if logged_in?
      current_user.interests.find_or_initialize_by(
        :in => item_id, 
        :interest_type => item_type
      )
    else
      Interest.new(
        :in => item_id, 
        :interest_type => item_type
      )
    end
  end

  # the interest need not be filled in with data
  def item_subscription_for(interest, subscription_type)
    interest.subscriptions.new(
      :interest_in => interest.in, :subscription_type => subscription_type,
      :user => current_user
    )
  end

end
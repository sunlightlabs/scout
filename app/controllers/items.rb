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
  item_id = params[:item_id]
  
  interest = item_interest_for item_id, item_type
  halt 404 and return unless interest.new_record?

  unless item = Subscriptions::Manager.find(item_types[item_type]['adapter'], item_id)
    halt 404 and return
  end

  interest.data = item.data
  subscriptions = item_subscriptions_for interest

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

  interest = item_interest_for params[:item_id], params[:item_type]
  halt 404 and return unless interest and !interest.new_record?

  interest.destroy
  halt 200
end


helpers do
  def item_interest_for(item_id, item_type)
    criteria = {
      :in => item_id, 
      :interest_type => 'item',
      :item_type => item_type
    }

    if logged_in?
      current_user.interests.find_or_initialize_by criteria
    else
      Interest.new criteria
    end
  end

  # the interest need not be filled in with data
  def item_subscription_for(interest, subscription_type)
    interest.subscriptions.new(
      :interest_in => interest.in, :subscription_type => subscription_type,
      :user => current_user,
      :data => interest.data # pass on item data to child subscriptions
    )
  end

  def item_subscriptions_for(interest)
    types = item_types[interest.item_type]['subscriptions'] || []
    types.map do |subscription_type| 
      item_subscription_for interest, subscription_type
    end
  end

end
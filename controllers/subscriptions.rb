# delete the subscription, and, if it's the last subscription under the interest, delete the interest
delete '/subscription/:id' do
  requires_login

  if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    halt 404 unless interest = Interest.where(:user_id => current_user.id, :_id => subscription.interest_id).first

    deleted_interest = false

    if interest.subscriptions.count == 1
      interest.destroy
      deleted_interest = true
    end

    subscription.destroy

    pane = deleted_interest ? nil : partial("partials/interest", :engine => "erb", :locals => {:interest => interest})

    headers["Content-Type"] = "application/json"
    {
      :deleted_interest => deleted_interest,
      :interest_id => interest.id.to_s,
      :pane => pane
    }.to_json
  else
    halt 404
  end
end

delete '/interest/:id' do
  requires_login
  
  if interest = current_user.interests.where(:_id => BSON::ObjectId(params[:id].strip)).first
    subscriptions = interest.subscriptions.to_a
    
    interest.destroy
    subscriptions.each do |subscription|
      subscription.destroy
    end
    
    halt 200
  else
    halt 404
  end
end

post '/interest/track' do
  requires_login

  interest_type = params[:interest_type]
  item_id = URI.decode params[:item_id] # can possibly have spaces, decode first
  
  unless item = Subscriptions::Manager.find(interest_data[interest_type][:adapter], item_id)
    halt 404 and return
  end

  interest = current_user.interests.new :interest_type => interest_type, :in => item_id, :data => item.data

  subscriptions = interest_data[interest_type][:subscriptions].keys.map do |subscription_type|
    current_user.subscriptions.new :interest_in => item_id, :subscription_type => subscription_type
  end

  if interest.valid? and (subscriptions.reject {|s| s.valid?}.empty?)
    interest.save!
    subscriptions.each do |subscription|
      subscription[:interest_id] = interest.id
      subscription.save!
    end

    headers["Content-Type"] = "application/json"
    {
      :interest_id => interest.id.to_s,
      :pane => partial("partials/interest", :engine => "erb", :locals => {:interest => interest})
    }.to_json
  else
    halt 500
  end
end



delete '/interest/untrack' do
  requires_login

  unless interest = current_user.interests.where(:_id => BSON::ObjectId(params[:interest_id].strip)).first
    halt 404 and return
  end

  subscriptions = interest.subscriptions.to_a
    
  interest.destroy
  subscriptions.each do |subscription| 
    subscription.destroy
  end
  
  halt 200
end

post '/subscriptions' do
  requires_login

  query = params[:interest].strip
  subscription_type = params[:subscription_type]

  new_interest = false

  # if this is editing an existing one, find it
  if params[:interest_id].present?
    interest = current_user.interests.find params[:interest_id]
  end

  # default to a new one
  if interest.nil?
    interest = current_user.interests.new(
      :in => query, 
      :interest_type => "search",
      :data => {
        'query' => query
      }
    )
    new_interest = true
  end
  
  subscription = current_user.subscriptions.new(
    :interest_in => query, 
    :subscription_type => subscription_type
  )

  if params[:subscription_data]
    subscription.data = params[:subscription_data]
  end
  
  headers["Content-Type"] = "application/json"

  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscription.valid?
    interest.save!
    subscription[:interest_id] = interest.id
    subscription.save!
    
    {
      :interest_id => interest.id.to_s,
      :subscription_id => subscription.id.to_s,
      :new_interest => new_interest,
      :pane => partial("partials/interest", :engine => "erb", :locals => {:interest => interest})
    }.to_json
  else
    halt 500
  end
  
end
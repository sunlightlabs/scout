# landing pages

get "/item/:item_type/:item_id" do
  interest = item_interest

  item_type = params[:item_type].strip
  item_id = params[:item_id].strip
  subscription_type = item_types[item_type]['adapter']

  if item = Subscriptions::Manager.find(subscription_type, item_id, {cache_only: !crawler?})
    interest = item_interest
    interest.data = item.data # required for the interest to know its own title

    content = erb :"subscriptions/#{subscription_type}/_show", layout: false, locals: {
      item: item,
      interest: interest,
      item_type: item_type
    }
    
    share = partial "partials/share", engine: :erb
    title = interest.title
  else
    content = nil
    share = nil
    title = nil
  end

  erb :show, layout: !pjax?, locals: {
    # if blank, will be ajaxed in later at the /fetch endpoint
    content: content, 
    share: share,

    # only used if it's cached or for a spider
    title: title,

    interest: interest,
    subscriptions: Interest.subscriptions_for(interest),
    item_type: params[:item_type],
    item_id: params[:item_id]
  }
end

get "/fetch/item/:item_type/:item_id" do
  valid_item
  
  item_type = params[:item_type].strip
  item_id = params[:item_id].strip
  subscription_type = item_types[item_type]['adapter']

  unless item = Subscriptions::Manager.find(subscription_type, item_id)
    halt 404 and return
  end

  interest = item_interest

  share = partial "partials/share", engine: :erb

  results = erb :"subscriptions/#{subscription_type}/_show", layout: false, locals: {
    item: item,
    interest: interest,
    item_type: item_type
  }

  json 200, {share: share, results: results}
end

get "/fetch/item/:item_type/:item_id/:subscription_type" do
  valid_item

  interest = item_interest

  # pass regenerate=true flag because we don't need the saved subscription, even if there is one
  subscription = Interest.subscription_for interest, params[:subscription_type], true

  # todo: this comes back nil as a race condition when occurring in parallel with a follow action
  items = subscription.search

  if items.is_a?(Hash)
    puts "[#{params[:subscription_type]}][#{params[:item_id]}][search] ERROR while loading this:\n\n#{JSON.pretty_generate items}" unless Sinatra::Application.test?
    items = nil # frontend gets nil
  end

  partial "show_results", engine: :erb, locals: {
    interest: interest,
    subscription: subscription,
    items: items
  }
end

post '/item/:item_type/:item_id/follow' do
  requires_login

  item_type = params[:item_type]
  item_id = params[:item_id]
  
  interest = item_interest
  halt 200 and return unless interest.new_record?

  # todo: kill now that the map is fixed
  adapter = if item_types[item_type] and item_types[item_type]['adapter']
    item_types[item_type]['adapter']
  else
    item_type.pluralize
  end
  
  unless item = Subscriptions::Manager.find(adapter, item_id)
    halt 404 and return
  end

  # populate the new interest with its actual fetched data
  interest.data = item.data

  interest.save!
  halt 200
end


delete '/item/:item_type/:item_id/unfollow' do
  requires_login

  interest = item_interest
  halt 404 and return unless interest and !interest.new_record?

  interest.destroy
  halt 200
end


helpers do
  def valid_item
    halt 404 and return unless type = item_types[params[:item_type]]
    if params[:subscription_type]
      halt 404 unless type['subscriptions'].include?(params[:subscription_type])
    end
  end

  def item_interest
    item_id = params[:item_id].strip
    item_type = params[:item_type].strip

    Interest.for_item current_user, item_id, item_type
  end

end
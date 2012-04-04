get "/account/:id.:format" do
  unless user = User.where(:_id => BSON::ObjectId(params[:id])).first
    halt 404 and return
  end

  items = SeenItem.where(:user_id => user.id).desc(:date)

  if params[:format] == 'rss'
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > 200000000
    per_page = 100
    items = items.skip(per_page * (page - 1)).limit(per_page)

    headers["Content-Type"] = "application/rss+xml"
    erb :"rss/user", :layout => false, :locals => {
      :items => items,
      :url => request.url
    }
  else
    json_for items, params
  end
end

get /\/interest\/([\w\d]+)\.?(\w+)?$/ do |interest_id, ext|
  # do not require login
  # for RSS, want readers and bots to access it freely
  # for SMS, want users on phones to see items easily without logging in
  # for JSON, no need to require an API key for now

  unless ['rss', 'json', nil, ''].include?(ext)
    halt 404 and return
  end

  unless interest = Interest.find(interest_id.strip)
    halt 404 and return
  end

  items = SeenItem.where(:interest_id => interest.id).desc(:date)

  # handle JSON completely separately
  if ext == 'json'
    return json_for items, params
  end
  
  page = (params[:page] || 1).to_i
  page = 1 if page <= 0 or page > 200000000
  per_page = (ext == 'rss') ? 100 : 20

  
  items = items.skip(per_page * (page - 1)).limit(per_page)

  if ext == 'rss'
    headers["Content-Type"] = "application/rss+xml"
    erb :"rss/interest", :layout => false, :locals => {
      :items => items, 
      :interest => interest,
      :url => request.url
    }

  # HTML version only works if the interest is a keyword search
  else 
    erb :"sms", :locals => {
      :items => items,
      :interest => interest
    }
  end
end


helpers do
  
  def json(results, params)
    response['Content-Type'] = 'application/json'
    json = results.to_json
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end


  def json_for(items, params)
    count = items.count
    
    pagination = pagination_for params
    skip = pagination[:per_page] * (pagination[:page]-1)
    limit = pagination[:per_page]
    items = items.skip(skip).limit(limit)

    results = {
      :results => items.map {|item| item.json_view},
      :count => count,
      :page => {
        :count => items.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }

    json results, params
  end


  def pagination_for(params)
    default_per_page = 50
    max_per_page = 50
    max_page = 200000000 # let's keep it realistic
    
    # rein in per_page to somewhere between 1 and the max
    per_page = (params[:per_page] || default_per_page).to_i
    per_page = default_per_page if per_page <= 0
    per_page = max_per_page if per_page > max_per_page
    
    # valid page number, please
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > max_page
    
    {:per_page => per_page, :page => page}
  end

end
# search results

get '/search/:subscription_type/:query/?:query_type?' do
  halt 404 and return unless (search_types + ["all"]).include?(params[:subscription_type])

  query = stripped_query

  interest = search_interest_for query, params[:subscription_type]
  subscriptions = Interest.subscriptions_for interest


  # see if we have cached content for any of these. if so, we'll render the cached items
  # directly and pass it down now, so the client doesn't need to fetch them.
  cached = {}
  subscriptions.each do |subscription|
    type = subscription.subscription_type
    
    if (results = subscription.search(page: 1, per_page: 20, cache_only: !crawler?)) and results.is_a?(Array)
      cached[type] = erb :"search/items", layout: false, locals: {
        items: results, 
        subscription: subscription,
        interest: interest,
        query: query,
        sole: (subscriptions.size  == 1),
        page: 1,
        per_page: (subscriptions.size == 1) ? 20 : 2 # per_page cutoff at the client level
      }
    end
  end

  # render the search skeleton, possibly with a hash of cached content keyed by search type
  erb :"search/search", layout: !pjax?, locals: {
    interest: interest,

    subscriptions: subscriptions,
    subscription: (subscriptions.size == 1 ? subscriptions.first : nil),

    cached: cached,

    related_interests: related_interests(interest),
    query: query,
    title: page_title(interest)
  }
end

get '/fetch/search/:subscription_type/:query/?:query_type?' do
  query = stripped_query
  subscription_type = params[:subscription_type]

  # make a fake interest, it may not be the one that's really generating this search request
  interest = search_interest_for query, params[:subscription_type]
  subscription = Interest.subscriptions_for(interest).first
  
  page = params[:page].present? ? params[:page].to_i : 1

  # only used to decide how many to display
  per_page = params[:per_page].present? ? params[:per_page].to_i : nil

  # perform the remote search, pass along page number and default per_page of 20
  results = subscription.search page: page, per_page: 20
    
  # if results is nil, it usually indicates an error in one of the remote services
  if results.nil?
    puts "[#{subscription_type}][#{query}][search] ERROR (unknown) while loading this"
  elsif results.is_a?(Hash)
    puts "[#{subscription_type}][#{query}][search] ERROR while loading this:\n\n#{JSON.pretty_generate results}"
    results = nil # frontend gets nil
  end
  
  items = erb :"search/items", layout: false, locals: {
    items: results, 
    subscription: subscription,
    interest: interest,
    query: query,
    sole: (per_page.to_i > 5),
    page: page,
    per_page: per_page
  }

  headers["Content-Type"] = "application/json"
  {
    html: items,
    count: (results ? results.size : -1),
    sole: (per_page.to_i > 5),
    page: page,
    per_page: per_page
  }.to_json
end

post '/interests/search' do
  requires_login

  query = stripped_query

  interest = search_interest_for query, params[:search_type]
  halt 200 and return unless interest.new_record?
  
  if interest.save
    interest_pane = partial "search/related_interests", :engine => :erb, :locals => {
      related_interests: related_interests(interest), 
      current_interest: interest,
      interest_in: interest.in
    }

    json 200, {
      interest_pane: interest_pane
    }
  else
    json 500, {
      errors: {
        interest: interest.errors.full_messages,
        subscription: (interest.subscriptions.any? ? interest.subscriptions.first.errors.full_messages : nil)
      }
    }
  end
end

delete '/interests/search' do
  requires_login

  query = stripped_query
  search_type = params[:search_type]

  interest = search_interest_for query, params[:search_type]
  halt 404 and return false if interest.new_record?
  
  interest.destroy

  interest_pane = partial "search/related_interests", :engine => :erb, :locals => {
    related_interests: related_interests(interest), 
    current_interest: nil,
    interest_in: interest.in
  }

  json 200, {
    interest_pane: interest_pane
  }
end



helpers do

  def search_interest_for(query, search_type)
    Interest.for_search current_user, search_type, query, query_type, params[search_type]
  end

  def related_interests(interest)
    if logged_in?
      current_user.interests.where(
        in_normal: interest.in_normal, 
        interest_type: "search",
        query_type: query_type
      )
    end
  end

  def query_type
    params[:query_type] || "simple"
  end

  def stripped_query
    query = params[:query] ? URI.decode(params[:query]).strip : nil

    # don't allow plain wildcards
    query = query.gsub /^[^\w]*\*[^\w]*$/, ''
    
    if query_type == "simple"
      query = query.tr "\"", ""
    elsif query_type == "advanced"
      query = query.tr ",:", ""
    end

    halt 404 unless query.present?
    halt 404 if query.size > 300 # sanity

    query
  end

end
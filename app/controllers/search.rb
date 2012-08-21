# search results

get '/search/:subscription_type/:query/?:query_type?' do
  halt 404 and return unless (search_types + ["all"]).include?(params[:subscription_type])

  query = stripped_query

  interest = search_interest_for query, params[:subscription_type]
  subscriptions = Interest.subscriptions_for interest

  erb :"search/search", :layout => !pjax?, :locals => {
    :interest => interest,

    :subscriptions => subscriptions,
    :subscription => (subscriptions.size == 1 ? subscriptions.first : nil),

    :related_interests => related_interests(interest.in),
    :query => query
  }
end

get '/fetch/search/:subscription_type/:query/?:query_type?' do
  query = stripped_query
  subscription_type = params[:subscription_type]

  # make a fake interest, it may not be the one that's really generating this search request
  interest = search_interest_for query, params[:subscription_type]
  subscription = Interest.subscriptions_for(interest).first
  
  page = params[:page].present? ? params[:page].to_i : 1
  per_page = params[:per_page].present? ? params[:per_page].to_i : nil

  # perform the remote search, pass along pagination preferences
  results = subscription.search :page => page, :per_page => per_page
    
  # if results is nil, it usually indicates an error in one of the remote services
  if results.nil?
    puts "[#{subscription_type}][#{query}][search] ERROR (unknown) while loading this"
  elsif results.is_a?(Hash)
    puts "[#{subscription_type}][#{query}][search] ERROR while loading this:\n\n#{JSON.pretty_generate results}"
    results = nil # frontend gets nil
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
  
  if interest.save
    interest_pane = partial "search/related_interests", :engine => :erb, :locals => {
      related_interests: related_interests(interest.in), 
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
        subscription: subscriptions.first.errors.full_messages
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
    related_interests: related_interests(interest.in), 
    current_interest: nil,
    interest_in: interest.in
  }

  json 200, {
    interest_pane: interest_pane
  }
end



helpers do

  def search_interest_for(query, search_type)
    data = {}
    data['query_type'] = query_type

    # default query field to original query, may change in post-processing
    data['query'] = query

    # default interest's 'in' field to original query, before post-processing.
    # returned interest may have a different 'in' field, 
    # if the normalized interest already existed under a different original search
    interest_in = query
    original_in = query


    if query_type == "simple"
      if citation_id = Search.usc_check(query)
        data['citation_type'] = 'usc'
        data['citation_id'] = citation_id
        data['query'] = nil # don't need to do full text search anymore
        interest_in = Search.usc_standard citation_id

        # if this is coming in as an invalid search_type 
        # for this kind of citation, switch it to 'all'
        if !Interest.search_types_for(data['citation_type']).include?(search_type)
          search_type = "all"
        end
      end
    end

    # merge in filters
    data.merge!(params[search_type] || {})

    Interest.for_search current_user, search_type, interest_in, original_in, data
  end

  def related_interests(interest_in)
    if logged_in?
      current_user.interests.where(
        :in => interest_in, 
        :interest_type => "search",
        "data.query_type" => query_type
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
      query = query.gsub "\"", ""
    elsif query_type == "advanced"
      query = query.gsub ":", ""
    end

    halt 404 unless query.present?
    halt 404 if query.size > 300 # sanity

    query
  end

end
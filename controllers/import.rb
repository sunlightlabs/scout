# Endpoints for managing the import of RSS feeds


# landing page to begin, preview, and finalize the import of an RSS feed
get "/import/feed" do
  erb :"account/import"
end

# fetch a preview of the given RSS feed
get "/import/feed/preview" do
  #TODO: detect if the user has one already on preview

  url = params[:url] ? params[:url].strip : ""

  subscription = Subscription.new(
    :subscription_type => "external_feed",
    :interest_in => url,
    :data => {
      'url' => url
    }
  )

  begin
    doc = Subscriptions::Adapters::ExternalFeed.url_to_response url
  rescue Exception => ex
    # return error
    halt 500 and return
  end

  halt 500 and return unless doc

  feed_details = Subscriptions::Adapters::ExternalFeed.feed_details doc

  unless results = subscription.search
    halt 500 and return # invalid feed or other problem
  end

  items = erb :"search/items", :layout => false, :locals => {
    :items => results, 
    :subscription => subscription,
    :query => nil,
    :sole => true
  }

  headers["Content-Type"] = "application/json"
  {
    :title => feed_details['title'],
    :description => feed_details['description'],
    :size => items.size,
    :html => items
  }.to_json
end


get "/import/feed/create" do
  # create the actual subscription for the RSS feed, and initialize it
  # create the interest as well, throw the data into it
  # email the admin about the new RSS feed in the system, for (reactive) review

end
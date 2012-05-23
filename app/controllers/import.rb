# Endpoints for managing the import of RSS feeds


# landing page to begin, preview, and finalize the import of an RSS feed
get "/import/feed" do
  erb :"account/import", :locals => {:url => (params[:url] || "").strip}
end

# fetch a preview of the given RSS feed
get "/import/feed/preview" do
  url = params[:url] ? params[:url].strip : ""

  unless feed_details = Subscriptions::Adapters::ExternalFeed.validate_feed(url)
    halt 500 and return
  end

  subscription = feed_subscription_from url
  unless results = subscription.search
    halt 500 and return
  end

  items = erb :"search/items", :layout => false, :locals => {
    :items => results.first(2), 
    :subscription => subscription,

    # could be removed if the partials were refactored not to necessarily expect these
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


post "/import/feed/create" do
  requires_login

  url = params[:url].present? ? params[:url].strip : nil
  title = params[:title].present? ? params[:title].strip : nil
  description = params[:description].present? ? params[:description].strip : nil

  unless url.present? and title.present? and feed_details = Subscriptions::Adapters::ExternalFeed.validate_feed(url)
    halt 500 and return
  end

  subscription = feed_subscription_from url
  subscription.data['title'] = title
  subscription.data['description'] = description
  subscription.data['original_title'] = feed_details['title']
  subscription.data['original_description'] = feed_details['description']

  interest = current_user.interests.new(
    :in => url,
    :interest_type => "external_feed",
    :data => subscription.data.dup
  )

  # should be non-controversial at this step
  interest.save!
  subscription.interest_id = interest.id
  subscription.save!

  # send admin an email about new feed, for reactive review
  Admin.new_feed interest

  json 200, {:interest_id => interest.id}
end

helpers do
  
  def feed_subscription_from(url)
    (current_user ? current_user.subscriptions : Subscription).new(
      :subscription_type => "external_feed",
      :interest_in => url,
      :data => {
        'url' => url
      }
    )
  end

end
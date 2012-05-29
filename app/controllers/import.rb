# Endpoints for managing the import of RSS feeds
require 'feedbag'


# landing page to begin, preview, and finalize the import of an RSS feed
get "/import/feed" do
  erb :"account/import", :locals => {:url => (params[:url] || "").strip}
end

# fetch a preview of the given RSS feed
get "/import/feed/preview" do
  url = params[:url] ? params[:url].strip : ""


  unless feed = Subscriptions::Adapters::Feeds.url_to_response(url)

    # give a try at autodiscovery
    urls = Timeout::timeout(5) {Feedbag.find url}
    url = urls.first

    unless url and (feed = Subscriptions::Adapters::Feeds.url_to_response(url))
      halt 500 and return
    end
  end

  feed_details = Subscriptions::Adapters::Feeds.feed_details feed
  feed_url = feed_details['feed_url'] || url

  subscription = feed_subscription_from feed_url
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
    :feed_url => feed_url,
    :size => items.size,
    :html => items
  }.to_json
end


post "/import/feed/create" do
  requires_login

  url = params[:url].present? ? params[:url].strip : nil
  original_url = params[:original_url].present? ? params[:original_url].strip : nil
  title = params[:title].present? ? params[:title].strip : nil
  description = params[:description].present? ? params[:description].strip : nil

  # for creating, a valid feed URL and title need to be prepared already
  unless url.present? and title.present? and 
    (feed = Subscriptions::Adapters::Feeds.url_to_response(url)) and
    (feed_details = Subscriptions::Adapters::Feeds.feed_details(feed))
    halt 500 and return
  end

  # what the user gave us may not be the feed's preferred canonical URL
  # we'll store and use that canonical URL

  # create subscription by the canonical URL
  subscription = feed_subscription_from url

  # details used to render and link to feed
  subscription.data['title'] = title
  subscription.data['description'] = description
  subscription.data['site_url'] = feed_details['site_url']

  # record what the user originally put in as a URL
  subscription.data['original_url'] = original_url

  # record what the feed originally listed as its title and description
  subscription.data['original_title'] = feed_details['title']
  subscription.data['original_description'] = feed_details['description']


  interest = current_user.interests.new(
    :in => url,
    :interest_type => "feed",
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
      :subscription_type => "feed",
      :interest_in => url,
      :data => {
        'url' => url
      }
    )
  end

end
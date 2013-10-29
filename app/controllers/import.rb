
# landing page to begin, preview, and finalize the import of an RSS feed
get "/import/feed" do
  erb :import, locals: {url: (params[:url] || "").strip}, layout: !pjax?
end

# fetch a preview of the given RSS feed
get "/import/feed/preview" do
  url = params[:url] ? params[:url].strip : ""

  begin
    unless feed = Subscriptions::Adapters::Feed.url_to_response(url)

      # give a try at autodiscovery
      urls = Timeout::timeout(5) {
        urls = Feedbag.find url

        # manually handle http->https error
        if urls.empty? and !url.start_with?("https:")
          url = url.start_with?("http:") ? url : "http://#{url}"
          Feedbag.find url.sub(/^http:/, "https:")
        else
          urls
        end
      }
      url = urls.first

      unless url and (feed = Subscriptions::Adapters::Feed.url_to_response(url))
        halt 500 and return
      end
    end
  rescue Subscriptions::AdapterParseException => ex
    puts "Error: #{ex.message}"
    halt 500 and return
  end

  feed_details = Subscriptions::Adapters::Feed.feed_details feed
  feed_url = feed_details['feed_url'] || url

  interest = Interest.for_feed nil, url
  subscription = Interest.subscriptions_for(interest).first

  unless results = subscription.search
    halt 500 and return
  end

  # error_for returns this
  if results.is_a?(Hash)
    puts "Bad feed: #{results.inspect}"
    halt 500 and return
  end

  items = erb :"search/items", layout: false, locals: {
    items: results.first(3),
    subscription: subscription,
    interest: interest,

    # could be removed if the partials were refactored not to necessarily expect these
    query: nil,
    sole: true
  }

  headers["Content-Type"] = "application/json"
  {
    title: feed_details['title'],
    description: feed_details['description'],
    feed_url: feed_url,
    size: items.size,
    html: items
  }.to_json
end


post "/import/feed/create" do
  requires_login

  url = params[:url].present? ? params[:url].strip : nil
  original_url = params[:original_url].present? ? params[:original_url].strip : nil
  title = params[:title].present? ? params[:title].strip : nil
  description = params[:description].present? ? params[:description].strip : nil

  # for creating, a valid feed URL and title need to be prepared already
  begin
    unless url.present? and title.present? and
      (feed = Subscriptions::Adapters::Feed.url_to_response(url)) and
      (feed_details = Subscriptions::Adapters::Feed.feed_details(feed))
      halt 500 and return
    end
  rescue Subscriptions::AdapterParseException => ex
    halt 500 and return
  end

  # what the user gave us may not be the feed's preferred canonical URL
  # we'll store and use that canonical URL

  # create interest by the canonical URL
  interest = Interest.for_feed current_user, url

  # details used to render and link to feed
  interest.data['url'] = url
  interest.data['title'] = title
  interest.data['description'] = description
  interest.data['site_url'] = feed_details['site_url']

  # record what the user originally put in as a URL
  interest.data['original_url'] = original_url

  # record what the feed originally listed as its title and description
  interest.data['original_title'] = feed_details['title']
  interest.data['original_description'] = feed_details['description']

  if interest.new_record?
    interest.save!
    Admin.new_feed interest
  end

  json 200, {interest_id: interest.id}
end
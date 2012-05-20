# router helpers, can also be mixed in elsewhere if need be
module Helpers
  module Routing

    # for item interests
    def interest_adapter(interest)
      Subscription.adapter_for(item_types[interest.item_type]['adapter'])
    end

    def interest_name(interest)
      if interest.item?
        interest_adapter(interest).interest_name interest
      elsif interest.feed?
        ::Subscriptions::Adapters::ExternalFeed.interest_name interest
      elsif interest.search?
        interest.in
      end
    end

    # temporary
    def item_type_name(item_type)
      {
        'state_bill' => 'State Bill',
        'bill' => 'Bill'
      }[item_type]
    end

    def interest_path(interest)
      if interest.item?
        "/item/#{interest.item_type}/#{interest.in}"
      elsif interest.feed?
        interest.in # URL
      elsif interest.search?
        search_interest_path interest
      end
    end

    def search_interest_path(interest)
      if interest.search_type == "all"
        base = "/search/all"
        base << "/#{URI.encode interest.data['query']}" if interest.data['query']
        base
      else
        subscription_path interest.subscriptions.first
      end
    end

    # given a subscription, serialize it to a URL
    # assumes it is a search subscription
    def subscription_path(subscription)
      base = "/search/#{subscription.subscription_type}"
      
      base << "/#{URI.encode subscription.data['query']}" if subscription.data['query']

      query_string = subscription.filters.map do |key, value| 
        "#{subscription.subscription_type}[#{key}]=#{URI.encode value}"
      end.join("&")
      base << "?#{query_string}" if query_string.present?

      base
    end
    
    def item_path(item)
      if item.item?
        "/item/#{item.item_type}/#{item.interest_in}##{item.item_id}"
      elsif item.feed?
        item.data['link']
      elsif item.search?
        "/item/#{item.item_type}/#{item.item_id}"
      end
    end

    def item_url(item)
      if item.subscription_type == "external_feed"
        item.data['link']
      else
        "http://#{config[:hostname]}#{item_path item}"
      end
    end

    def tag_path(user, tag)
      "/#{user.username || user.id.to_s}/#{URI.encode tag}"
    end

    # only needed in RSS feeds, and external feeds are the only time we override the guid
    def item_guid(item)
      if item.subscription_type == "external_feed"
        item.data['guid']
      else
        item_url item
      end
    end

    # URLs for the JSON feeds behid the searches, but with the user's API key
    def developer_search_url(subscription)
      subscription.search_url :api_key => api_key
    end

    def developer_find_url(item_type, item_id)
      adapter = Subscription.adapter_for item_types[item_type]['adapter']
      adapter.url_for_detail item_id, :api_key => api_key
    end

    # shrug
    def search?
      request.path =~ /^\/search\//
    end

  end
end
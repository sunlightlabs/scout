# router helpers, can also be mixed in elsewhere if need be
module Helpers
  module Routing
    
    def item_path(item)
      if item.subscription_type == "external_feed"
        item.data['link']

      # an item with its own landing page
      elsif item_type = search_adapters[item.subscription_type]
        "/item/#{item_type}/#{item.item_id}"

      # an item that does not have its own landing page
      else
        "/item/#{item.interest_type}/#{item.interest_in}##{item.item_id}"
      end
    end

    def item_url(item)
      if item.subscription_type == "external_feed"
        item.data['link']
      else
        "http://#{config[:hostname]}#{item_path item}"
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

  end
end
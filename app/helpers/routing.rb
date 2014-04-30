# router helpers, can also be mixed in elsewhere if need be

module Helpers
  module Routing

    def user_name(user)
      if user.display_name.present?
        user.display_name
      elsif user.username.present?
        user.username
      end
    end

    # for item interests
    def interest_adapter(interest)
      Subscription.adapter_for(item_types[interest.item_type]['adapter'])
    end

    # Warning: using keyword arg syntax in this way is new in Ruby 2.0!
    def interest_name(interest, long: false)
      if interest.item?
        if long
          interest_adapter(interest).title_for interest.data
        else
          interest_adapter(interest).interest_name interest
        end
      elsif interest.feed?
        interest.data['title']
      elsif interest.search?
        interest.in
      elsif interest.tag?
        if (name = user_name(interest.tag_user)).present?
          "#{name} &mdash; #{interest.tag.name.capitalize}"
        else
          interest.tag.name.capitalize
        end
      end
    end

    def interest_description(interest)
      description = if interest.search?
        if interest.search_type == "all"
          interest.subscriptions.map(&:search_name).join(", ")
        elsif interest.subscriptions.first.filters.any?
          filters_short interest.subscriptions.first
        end
      elsif interest.item?
        if interest_adapter(interest).respond_to?(:title_for)
          interest_adapter(interest).title_for interest.data
        end
      elsif interest.feed?
        interest.data['description']
      elsif interest.tag?
        interest.tag.description
      end

      if description.present?
        truncate_more("interest-#{interest.id}", description, 70)
      else
        nil
      end
    end

    def interest_feed_path(interest)
      if interest.feed?
        interest.data['url']
      elsif interest.tag?
        collection_feed_path interest.tag_user, interest.tag, "rss"
      else
        "/interest/#{interest.id}.rss"
      end
    end

    # frozen on interest at create/update time.
    def interest_path(interest)
      interest.path
    end

    # uses frozen path.
    def interest_url(interest)
      if interest.feed?
        interest_path interest
      else
        "#{Environment.config['hostname']}#{interest_path interest}"
      end
    end

    def item_path(item)
      item.path
    end

    def item_url(item, interest = nil, user = nil)
      if item.subscription_type == "feed"
        item.data['url']

      # special case: Open States users get direct links
      elsif interest and user and (user.service == "open_states")
        if interest.search? and interest.search_type == "state_bills"
          openstates_url item.data
        elsif interest.item? and interest.item_type == "state_bill"
          openstates_url interest.data
        elsif interest.item? and interest.item_type == "state_legislator"
          openstates_url item.data
        end

      # item subscription adapters must each define a direct_item_url method
      elsif item.item? and interest and
        (adapter = Subscription.adapter_for(item.subscription_type)) and
        (url = adapter.direct_item_url item.data, interest)
        url
      else
        "#{Environment.config['hostname']}#{item_path item}"
      end
    end

    # wraps the given URL in the redirect URL,
    # with an arbitrary hash of data to be query string encoded
    def redirect_url(url, data = {})
      data.merge! to: url
      "#{Environment.config['hostname']}/url?#{data.to_query}"
    end

    def email_url(url, data = {})
      if url !~ /^https?:/
        url = [Environment.config['hostname'], url].join
      end

      redirect_url url, {from: "email", d: data}
    end

    def email_item_url(item, interest = nil, user = nil)
      interest ||= item.interest
      user ||= item.user

      url = item_url item, interest, user

      data = {
        from: "email",
        d: {
          url_type: "item",
          item_id: item.item_id,
          subscription_type: item.subscription_type
        }
      }

      if interest
        data[:d][:interest_type] = interest.interest_type

        if interest.search?
          data[:d][:query] = interest.in
        end
      end

      if user and user.service.present?
        data[:d][:service] = user.service
      end

      redirect_url url, data
    end

    def user_id(user)
      if user.username.present?
        user.username
      else
        user.id.to_s
      end
    end

    def collection_path(user, collection)
      "/user/#{user_id user}/#{Tag.slugify collection.name}"
    end

    def collection_feed_path(user, collection, format)
      "#{collection_path user, collection}.#{format}"
    end

    # only needed in RSS feeds, and external feeds are the only time we override the guid
    def item_guid(item)
      if item.subscription_type == "feed"
        item.data['guid']
      else
        item_url item
      end
    end

    # URLs for the JSON feeds behind the searches, but with a demo API key
    def developer_search_url(subscription)
      subscription.search_url api_key: Environment.config['demo_key']
    end

    def developer_find_url(item_type, item_id)
      adapter = Subscription.adapter_for item_types[item_type]['adapter']
      adapter.url_for_detail item_id, api_key: Environment.config['demo_key']
    end

    # shrug
    # TODO: if we support us-code search URLs, this will need to change
    def searching?
      request.path =~ /^\/search\//
    end

    # convenience function to more easily do a map and join in the view
    def linked_search(interest)
      subscription = interest.subscriptions.first
      adapter = subscription.adapter
      "<a href=\"#{interest_path interest}\">
        #{adapter.short_name 2, adapter}</a>"
    end
  end
end
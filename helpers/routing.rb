# router helpers, can also be mixed in elsewhere if need be
module Routing
  def item_path(item)
    # an item with its own landing page
    if item_type = search_adapters[item.subscription_type]
      "/item/#{item_type}/#{item.item_id}"

    # an item that does not have its own landing page
    else
      "/item/#{item.interest_type}/#{item.interest_in}##{item.item_id}"
    end
  end

  def item_url(item)
    "http://#{config[:hostname]}#{item_path item}"
  end
end
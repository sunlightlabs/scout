# general display helpers
module GeneralHelpers
  helpers ::Padrino::Helpers

  def hide_search
    content_for(:hide_search) { true }
  end

  def set_home
    content_for(:home) { true }
  end

  def search?
    yield_content(:hide_search).blank?
  end

  def home?
    yield_content(:home).present?
  end

  def flash_for(types)
    partial "layout/flash", :engine => "erb", :locals => {:types => types}
  end

  def recent_searches
    partial "layout/recent_searches", :engine => "erb", :locals => {}
  end

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

  def interest_name(interest)
    if interest.item?
      Subscription.adapter_for(interest_data[interest.interest_type][:adapter]).interest_name(interest)
    else
      interest.in
    end
  end

  def safe_capitalize(string)
    words = string.split(" ")
    words.each {|word| word[0..0] = word[0..0].upcase}
    words.join(" ")
  end

  def rss_date(time)
    time.strftime "%a, %d %b %Y %H:%M:%S %z"
  end

  def rss_encode(link)
    link.gsub "&", "&amp;"
  end

  def html_date(time)
    time.strftime "%Y-%m-%d"
  end
  
  def h(text)
    Rack::Utils.escape_html(text)
  end
  
  def form_escape(string)
    string.to_s.gsub "\"", "&quot;"
  end

  def js_escape(string)
    URI.decode(string.to_s).gsub "\"", "\\\""
  end
  
  def id_escape(id)
    id.gsub(" ", "_").gsub("|", "__").gsub(".", "__")
  end
  
  def long_date(time)
    time.strftime "%B #{time.day}, %Y" # remove 0-prefix
  end

  def short_date(time)
    time.strftime "%m-%d-%Y"
  end
  
  def just_date(date)
    date.strftime "%b #{date.day}"
  end

  def just_date_year(date)
    # if date.year == Time.now.year
    #   just_date date
    # else
      date.strftime "%b #{date.day}, %Y"
    # end
  end
  
  def very_short_date(time)
    time.strftime "%m/%d"
  end
  
  def zero_prefix(number)
    number.to_i < 10 ? "0#{number}" : number.to_s
  end
  
end
helpers GeneralHelpers


# Subscription-specific helpers
require 'subscriptions/helpers'
helpers Subscriptions::Helpers
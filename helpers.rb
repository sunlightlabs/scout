# general display helpers
module GeneralHelpers
  helpers ::Padrino::Helpers

  def flash_for(types)
    partial "partials/flash", :engine => "erb", :locals => {:types => types}
  end
  
  # index of subscription adapters and associated copy
  def search_subscriptions
    @search_subscriptions ||= search_subscription_data
  end

  def interest_path(interest)
    "/#{interest.interest_type}/#{form_escape interest.in}"
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
    id.gsub(" ", "_").gsub("|", "__")
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
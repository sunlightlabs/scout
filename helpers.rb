# general display helpers
module GeneralHelpers
  
  # index of subscription adapters and associated copy
  def subscription_types
    @subscription_types ||= subscription_data
  end

  def interest_path(interest)
    "/#{interest.interest_type}/#{form_escape interest.in}"
  end

  def interest_name(interest)
    if interest.item?
      Subscription.adapter_for(item_data[interest.interest_type][:adapter]).item_name(interest.data)
    else
      interest.in
    end
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
  
  def url_escape(url)
    URI.escape url
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


# taken from https://gist.github.com/119874
module Sinatra::Partials
  def partial(template, *args)
    template_array = template.to_s.split('/')
    template = template_array[0..-2].join('/') + "/_#{template_array[-1]}"
    options = args.last.is_a?(Hash) ? args.pop : {}
    options.merge!(:layout => false)
    if collection = options.delete(:collection) then
      collection.inject([]) do |buffer, member|
        buffer << erb(:"#{template}", options.merge(:layout =>
        false, :locals => {template_array[-1].to_sym => member}))
      end.join("\n")
    else
      erb(:"#{template}", options)
    end
  end
end
helpers Sinatra::Partials
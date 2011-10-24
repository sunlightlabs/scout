# general display helpers
module GeneralHelpers
  
  # index of subscription adapters and associated copy
  def subscription_types
    {
      'federal_bills' => {
        :name => "Bills in Congress",
        :color => "#46517A"
      },
      'state_bills' => {
        :name => "Bills in the States",
        :color => "#7A5D46"
      },
      'congressional_record' => {
        :name => "Congressional Record",
        :color => "#467A74"
      }
    }
  end
  
  def h(text)
    Rack::Utils.escape_html(text)
  end
  
  def form_escape(string)
    string.to_s.gsub "\"", "&quot;"
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
    date.strftime "%B #{date.day}"
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
# general display helpers
module GeneralHelpers
  
  # index of subscription adapters and associated copy
  def subscription_types
    @subscription_types ||= {
      'federal_bills' => {
        :name => "Congress' Bills",
        :group => "congress",
        :order => 1,
        :color => "#46517A"
      },
      'state_bills' => {
        :name => "State Bills",
        :group => "states",
        :order => 3,
        :color => "#467A62"
      },
      'congressional_record' => {
        :name => "Congress' Speeches",
        :group => "congress",
        :order => 2,
        :color => "#51467A"
      }
    }
  end

  def subscription_groups
    @subscription_groups ||= {
      "congress" => {
        :name  => "Congress",
        :types => ["federal_bills", "congressional_record"],
        :color => "#46517A",
        :order => 1
      },
      "states" => {
        :name => "States",
        :types => ["state_bills"],
        :color => "#467A49",
        :order => 2
      }
    }
  end

  def subscription_groups_json
    "{\n%s\n}" % subscription_groups.map do |group, data|
      "#{group}: [#{data[:types].map {|t| "\"#{t}\""}.join(", ")}]"
    end.join(",\n")
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
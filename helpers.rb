helpers do
  
  def h(text)
    Rack::Utils.escape_html(text)
  end
  
  def form_escape(string)
    string.gsub "\"", "&quot;"
  end
  
  def url_escape(url)
    URI.escape url
  end
  
  def long_date(time)
    time.strftime "%B #{time.day}, %Y" # remove 0-prefix
  end
  
  # bill display helpers
  
  def bill_code(type, number)
    "#{bill_type type} #{number}"
  end
  
  def bill_type(short)
    {
      "hr" => "H.R.",
      "hres" => "H. Res.",
      "hjres" => "H. J. Res.",
      "hcres" => "H. C. Res.",
      "s" => "S.",
      "sres" => "S. Res.",
      "sjres" => "S. J. Res.",
      "scres" => "S. C. Res."
    }[short]
  end
  
  def bill_highlight(item)
    highlighting = item.data['search']['highlight']
    field = highlighting.keys.first
    
    "<dt>From #{highlight_field field}:</dt>\n<dd>#{highlighting[field]}</dd>"
  end
  
  def highlight_field(field)
    {
      "full_text" => "the full text",
      "summary" => "the summary",
      "official_title" => "the official title",
      "short_title" => "the official short title",
      "popular_title" => "the nickname",
    }[field]
  end
  
end

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
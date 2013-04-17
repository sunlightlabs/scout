require 'rinku'

# general display helpers
module Helpers
  module General

    def sadness
      sads = %w{regrettably sadly unfortunately inexplicably sadheartedly sorrowfully most-unpleasantly with-great-sadness}
      sad = sads[rand sads.size]
      sad.split('-').join(' ').capitalize
    end

    def page_title(interest)
      if (interest.query_type == "simple") and (interest.query['citations'] and interest.query['citations'].any?)
        name = Search.cite_standard interest.query['citations'].first
      else
        name = interest.in
      end

      if interest.search_type == "all"
        title = name
      else
        type = Subscription.adapter_for(interest.search_type).search_name nil
        title = "#{type}: #{name}"
      end

      title = "#{title} | Scout"
    end

    # takes in a hash of citation details from the interest query builder
    def cite_link(citation)
      if citation['citation_type'] == "law"
        law, type, congress, number = citation['citation_id'].split "/"
        if type == "public"
          "http://www.gpo.gov/fdsys/pkg/PLAW-#{congress}publ#{number}/pdf/PLAW-#{congress}publ#{number}.pdf"
        else # private
          "http://www.gpo.gov/fdsys/pkg/PLAW-#{congress}pvtl#{number}/pdf/PLAW-#{congress}pvtl#{number}.pdf"
        end
      else
        usc, title, section, *subsections = citation['citation_id'].split "/"
        "http://www.law.cornell.edu/uscode/text/#{title}/#{section}"
      end
    end

    # this takes in a Citation instance
    def cite_description(match)
      if match.citation_type == "usc"
        "<span class=\"usc_title\">#{match.usc['title_name']}</span>: #{match.description}"
      end
    end

    def query_size(query)
      if query.size < 30
        "smaller"
      elsif query.size < 80
        "medium"
      else
        "large"
      end
    end

    # temporary
    def item_type_name(item_type)
      {
        'state_bill' => 'State Bills',
        'bill' => 'Bills in Congress',
        'state_legislator' => 'State Legislators'
      }[item_type]
    end

    def notification_radio_for(type, checked, enabled)
      name = notification_name type

      "<input type=\"radio\" name=\"notifications\" class=\"notifications\" value=\"#{type}\" #{"checked" if checked} #{"disabled" unless enabled}/>
      <span class=\"#{"disabled" unless enabled}\">#{name}</span>"
    end

    def notification_name(type)
      {
        "email_immediate" => "Email immediately",
        "email_daily" => "Email once a day",
        "sms" => "SMS",
        "none" => "None",
        nil => "None",
        "" => "None"
      }[type]
    end

    def filters_short(subscription)
      subscription.filters.map do |field, value|
        "<span>#{subscription.filter_name field, value}</span>"
      end.join(", ")
    end

    def show_data?
      !api_key.nil?
    end

    def api_key
      if current_user and current_user.api_key
        current_user.api_key
      elsif params[:hood] == "up"
        config[:demo_key]
      end
    end

    def errors_for(object)
      if object and object.errors
        object.errors.full_messages.map do |msg|
          "<div class=\"error user\">#{msg}</div>"
        end.join
      end
    end

    def flash_for(types)
      partial "partials/flash", :engine => "erb", :locals => {:types => types}
    end

    def follow_button(item)
      partial "partials/follow_item", :engine => "erb"
    end

    def truncate(string, length)
      string ||= ""
      if string.size > length
        string[0...length] + "..."
      else
        string
      end
    end

    def truncate_more(tag, text, max)
      truncated = truncate text, max
      if truncated == text
        text
      else
        "<span class=\"truncated\" data-tag=\"#{tag}\">
          #{truncated}
          <a href=\"#\" class=\"untruncate text\">More</a>
        </span>
        <span class=\"untruncated\" data-tag=\"#{tag}\">
          #{text}
          <a href=\"#\" class=\"ununtruncate text\">Less</a>
        </span>"
      end
    end

    def truncate_more_html(tag, text, max, post = nil)
      truncated = truncate text, max
      
      text = simple_format text
      truncated = simple_format truncated

      # if a lambda for post processing is given, run it
      if post
        truncated = post.call truncated
        text = post.call text
      end

      if truncated == text
        text
      else
        "<div class=\"truncated\" data-tag=\"#{tag}\">
          #{truncated}
          <p><a href=\"#\" class=\"untruncate html\">More</a></p>
        </div>
        <div class=\"untruncated\" data-tag=\"#{tag}\">
          #{text}
          <p><a href=\"#\" class=\"ununtruncate html\">Less</a></p>
        </div>"
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
      if time.is_a?(String)
        time
      else
        time.strftime "%Y-%m-%d"
      end
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
    
    def long_date(date)
      date = Time.zone.parse(date) if date.is_a?(String)
      local = date.in_time_zone
      local.strftime "%B #{local.day}, %Y" # remove 0-prefix
    end

    def short_date(date)
      date = Time.zone.parse(date) if date.is_a?(String)
      local = date.in_time_zone
      local.strftime "%m-%d-%Y"
    end

    def just_time(date)
      date = Time.zone.parse(date) if date.is_a?(String)
      local = date.in_time_zone
      hour = local.strftime("%I").gsub(/^0/, "")
      "#{hour}#{local.strftime(":%M %p")}"
    end
    
    def just_date(date)
      date = Time.zone.parse(date) if date.is_a?(String)
      local = date.in_time_zone
      local.strftime "%b #{local.day}, %Y"
    end

    def just_date_no_year(date)
      date = Time.zone.parse(date) if date.is_a?(String)
      local = date.in_time_zone
      local.strftime "%b #{local.day}"
    end

    def just_date_year(date)
      date = Time.zone.parse(date) if date.is_a?(String)
      just_date date
    end
    
    def very_short_date(time)
      date = Time.zone.parse(date) if date.is_a?(String)
      local = time.in_time_zone
      local.strftime "%m/%d"
    end
    
    def zero_prefix(number)
      number.to_i < 10 ? "0#{number}" : number.to_s
    end

    def zero_prefix_five(number)
      n = number.to_i
      if n < 10
        "0000#{number}"
      elsif n < 100
        "000#{number}"
      elsif n < 1000
        "00#{number}"
      elsif n < 10000
        "0#{number}"
      else
        number.to_s
      end
    end

    def light_format(string)
      return "" unless string.present?
      string = strip_tags string
      string = simple_format string
      Rinku.auto_link string, :all, "rel='nofollow'"
    end

    
    # email-related
    
    def email_header(text, url)
      "<h3 style=\"padding: 0; margin: 0; margin-top: 30px;\">
        <a href=\"#{url}\">
          #{text}
        </a>
      </h3>"
    end

    def email_header_small(text, url)
      "<h3 style=\"padding: 0; margin: 0; margin-top: 30px\">
        <a href=\"#{url}\">
          #{text}
        </a>
      </h3>"
    end

    def email_subheader_div(space = 5)
      "<div style=\"padding: 0; margin: 0; margin-top: #{space}px; color: #83858B; font-style: italic\">"
    end

    def email_content_p(space = 10)
      "<p style=\"padding: 0; margin: 0; margin-top: #{space}px\">"
    end
  end
end
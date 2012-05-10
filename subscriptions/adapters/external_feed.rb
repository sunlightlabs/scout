require 'httparty'
require 'nokogiri'
require 'loofah'

module Subscriptions  
  module Adapters

    class ExternalFeed

      # data structure of an external RSS feed subscription/interest
      # data:
      #   url: [rss url]
      #   title: [title set by user (defaults to rss title)]
      #   original_title: [rss title]
      #   original_description: [rss description]
      

      def self.url_for(subscription, function, options = {})
        subscription.data['url']
      end

      def self.url_for_detail(item_id, options = {})
        item_id
      end

      
      # name methods

      def self.search_name(subscription)
        subscription.data['title']
      end

      def self.short_name(number, subscription, interest)
        "#{number > 1 ? "results" : "result"}"
      end

      def self.interest_name(interest)
        interest.data['title']
      end


      # go through each RSS item, exclude any invalid things

      def self.items_for(doc, function, options = {})
        return nil unless doc

        (doc / :item).map do |item|
          item_for item
        end.compact # item_for may return nil if it's invalid (no date or link)
      end

      def self.item_for(item)
        data = {}

        ['pubDate', 'title', 'description', 'link', 'guid'].each do |field|
          if value = item.at(field)
            data[field] = sanitize value.text
          end
        end

        date = nil
        link = nil

        if data['pubDate']
          date = Time.parse(data['pubDate']) rescue nil
        end

        if data['link'] and (URI.parse(data['link']) rescue nil)
          link = data['link']
        end

        return nil unless date and link

        # turn any HTML in the description into plain text
        data['description'] = strip_tags data['description']

        SeenItem.new(
          :item_id => link,
          :date => date,
          :data => data
        )
      end


      # RSS parsing stuff

      # The RSS adapter overrides the normal JSON parser, and includes extra security checks
      # since it can be given URLs from arbitrary external sources.

      def self.url_to_response(url)
        # ask for it in plaintext (turn off HTTParty's smart parsing), with a timeout of 5 seconds
        response = HTTParty.get url, :timeout => 5, :format => "text"
        
        # max size, 1MB
        return nil if response.to_s.size > (1024 * 1024 * 1)

        # check that the response is actual XML
        doc = Nokogiri::XML(response.to_s) {|config| config.strict} rescue nil

        return nil unless doc and (doc.root.name == "rss")

        doc
      end

      # extract feed-level details from the doc

      def self.feed_details(doc)
        details = {}

        if title = (doc / :title).first
          details['title'] = sanitize title.text
        end

        if description = (doc / :description).first
          details['description'] = sanitize description.text
        end

        details
      end

      # strip out unsafe HTML

      def self.sanitize(string)
        Loofah.scrub_fragment(string, :prune).to_s.strip
      end

      def self.strip_tags(string)
        doc = Nokogiri::HTML string
        (doc/"//*/text()").map do |text| 
          text.inner_text.strip
        end.select {|text| text.present?}.join " "
      end

    end

  end
end
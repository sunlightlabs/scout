require 'nokogiri'
require 'feedzirra'
require 'sanitize'

module Subscriptions
  module Adapters

    class Feed

      # data structure of an external RSS feed subscription/interest
      # data:
      #   url: [feed url]
      #   title: [title set by user (defaults to rss title)]
      #   description: [description set by user (defaults to rss description)]
      #   site_url: [url that feed listed as related]
      #
      #   original_url: [url as entered by user]
      #   original_title: [rss title]
      #   original_description: [rss description]


      def self.url_for(subscription, function, options = {})
        subscription.interest_in
      end

      def self.url_for_detail(item_id, options = {})
        item_id
      end


      # name methods

      def self.search_name(subscription)
        subscription.data['title']
      end

      def self.short_name(number, interest)
        number == 1 ? 'result' : 'results'
      end

      # go through each RSS item, exclude any invalid things

      def self.items_for(feed, function, options = {})
        raise AdapterParseException.new("Passed items_for a nil response, can't process this") unless feed

        items = feed.entries.map do |entry|
          item_for entry
        end.compact

        items
      end

      def self.item_for(entry)
        data = {}

        data['published'] = entry.published
        data['url'] = entry.url

        return nil unless data['published'] and data['url']

        # turn any HTML in the description into plain text
        content = entry.content.present? ? entry.content : entry.summary
        content = sanitize(content) if content.present?

        data['content'] = content

        if entry.title.present?
          data['title'] = sanitize entry.title
        else
          data['title'] = "(Untitled)"
        end

        SeenItem.new(
          item_id: data['url'],
          date: data['published'],
          data: data
        )
      end


      # RSS parsing stuff

      # The RSS adapter overrides the normal JSON parser, and includes extra security checks
      # since it can be given URLs from arbitrary external sources.

      def self.url_to_response(url)
        # first, verify the maximum size, so we don't choke
        xml = Feedzirra::Feed.fetch_raw url, timeout: 5

        raise AdapterParseException.new("Got null from fetching feed") unless xml
        raise AdapterParseException.new("Feed is bigger than 1MB") if xml.size > (1024 * 1024 * 1)

        # re-fetch it to take advantage of Feedzirra's full pipeline
        # (including proper logging of the final feed URL location)
        response = Feedzirra::Feed.fetch_and_parse url, timeout: 5

        raise AdapterParseException.new("Feed got invalid response code: #{response}") if response.is_a?(Fixnum)

        response
      end

      # extract feed-level details
      def self.feed_details(feed)
        details = {}

        if feed.title.present?
          details['title'] = sanitize feed.title
        end

        if feed.description.present?
          details['description'] = sanitize feed.description
        end

        if feed.url.present?
          details['site_url'] = sanitize feed.url
        end

        if feed.feed_url.present?
          details['feed_url'] = sanitize feed.feed_url
        end

        details
      end


      # strip out unsafe HTML, leave only links
      def self.sanitize(string)
        return nil unless string
        result = Sanitize.clean(string, elements: ['a'],
          attributes: {'a' => ['href', 'title']},
          protocols: {'a' => {'href' => ['http', 'https', 'mailto']}}
        )
      end

      # sent in a sanitized, truncated string, which could conceivably have
      # <a> tags cut off mid-html. parse, remove aborted <a>'s,
      # and re-serialize.
      def self.clean_truncated(html)
        return nil unless html.present?

        doc = Nokogiri::HTML html

        # Nokogiri creates a body, sometimes a p
        inner = doc.at("body") || doc.root
        inner = inner.at("p") if inner.at("p")

        last_link = (inner / :a).last
        if last_link && last_link.inner_text.blank?
          last_link.remove
          inner.inner_html + "…"
        else
          inner.inner_html
        end
      end

    end

  end
end
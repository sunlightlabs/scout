# Copyright (c) 2012, Sunlight Labs, under the terms of the Scout project's
# licensing.

module Subscriptions
  module Adapters

    class StateLegislatorsBills
      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']
        
        endpoint = "http://openstates.org/api/v1"

        fields = %w{ 
          id bill_id subjects state chamber created_at updated_at 
          title sources versions session %2Bshort_title 
          action_dates
        }
        
        legislator_id = subscription.interest_in

        url = "#{endpoint}/bills/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"

        url << "&sponsor_id=#{URI.encode legislator_id}"
        url << "&search_window=all"

        # this should still alert on every newly introduced bill, except under very weird circumstances
        # would be better to sort on introduced date, but I believe this it not always guaranteed
        url << "&sort=first"

        # for speed's sake, limit check to bills updated in last 2 months
        if function == :check
          last_action_since = (2.months.ago).strftime("%Y-%m-%dT%H:%M:%S")
          url << "&last_action_since=#{last_action_since}"
        end

        # pagination

        if options[:page]
          url << "&page=#{options[:page]}"
        end

        per_page = (function == :search) ? (options[:per_page] || 20) : 50
        url << "&per_page=#{per_page}"


        url
      end

      def self.search_name(subscription)
        "Legislator's Sponsored Bills"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "bills" : "bill"}"
      end

      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Got string response from Open States:\n\n#{response}") if response.is_a?(String)

        response.map {|bill| item_for bill}
      end

      def self.item_for(bill)
        # created_at and updated_at are UTC, take them directly as such
        ['updated_at', 'created_at'].each do |field|
          bill[field] = bill[field] ? bill[field].to_time : nil
        end

        if bill['actions']
          bill['actions'].each do |action|
            action['date'] = Time.zone.parse(action['date']) if action['date']
          end
        end

        if bill['votes']
          bill['votes'].each do |vote|
            vote['date'] = Time.zone.parse(vote['date']) if vote['date']
          end
        end

        if bill['action_dates']
          bill['action_dates'].keys.each do |key|
            bill['action_dates'][key] = Time.zone.parse(bill['action_dates'][key]) if bill['action_dates'][key]
          end
        end

        # use first action (introduction date) for a sponsored bills feed
        # first action should always be present, but just in case, default to created date
        if bill['action_dates'] and bill['action_dates']['first']
          date = bill['action_dates']['first']
        else
          date = bill['created_at']
        end

        SeenItem.new(
          item_id: bill['id'],
          date: date,
          data: bill
        )
      end
    end
  end
end

# vim: tabstop=2 expandtab shiftwidth=2 softtabstop=2

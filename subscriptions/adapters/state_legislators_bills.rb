# Copyright (c) 2012, Sunlight Labs, under the terms of the Scout project's
# licensing.

module Subscriptions
  module Adapters

    class StateLegislatorsBills
      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        endpoint = "http://openstates.org/api/v1"
        query = subscription.query['query']
        url = "#{endpoint}/bills/?sponsor_id=#{URI.encode query}&apikey=#{api_key}"
        # Currently, we only really care about bills that this person
        # sponsored. No need to get too fancy yet
        url
      end

      def self.search_name(subscription)
        "Legislator's Bills"
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

        SeenItem.new(
          :item_id => bill['id'],
          :date => bill["created_at"],
          :data => bill
        )
      end
    end
  end
end

# vim: tabstop=2 expandtab shiftwidth=2 softtabstop=2

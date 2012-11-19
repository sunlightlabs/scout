# Copyright (c) 2012, Sunlight Labs, under the terms of the Scout project's
# licensing.

module Subscriptions
  module Adapters

    class StateLegislators
      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        endpoint = "http://openstates.org/api/v1"
        url = "#{endpoint}/legislators/#{URI.encode item_id}/?apikey=#{api_key}"
        url
      end

      def self.interest_name(interest)
        "Bills co-sponsored by #{interest.data['full_name']}"
      end

      def self.item_for(legislator)
        # created_at and updated_at are UTC, take them directly as such
        ['updated_at', 'created_at'].each do |field|
          legislator[field] = legislator[field] ? legislator[field].to_time : nil
        end
        SeenItem.new(
          :item_id => legislator['id'],
          :date => legislator["created_at"],
          :data => legislator
        )
      end

      def self.item_detail_for(legislator)
        return nil unless legislator
        item_for legislator.to_hash
      end
    end
  end
end

# vim: tabstop=2 expandtab shiftwidth=2 softtabstop=2

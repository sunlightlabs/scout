module Subscriptions
  module Adapters

    class StateLegislators
      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        endpoint = "http://openstates.org/api/v1"
        url = "#{endpoint}/legislators/#{URI.encode item_id}/?apikey=#{api_key}"
        url
      end

      def self.item_detail_for(legislator)
        return nil unless legislator
        item_for legislator.to_hash
      end
  end
end

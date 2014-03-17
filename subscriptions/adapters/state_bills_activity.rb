module Subscriptions
  module Adapters

    class StateBillsActivity
      ITEM_TYPE = 'state_bill'
      ITEM_ADAPTER = true

      def self.url_for(subscription, function, options = {})
        endpoint = "http://openstates.org/api/v1"
        api_key = options[:api_key] || Environment.config['subscriptions']['sunlight_api_key']

        fields = %w{ id bill_id state chamber session actions }

        item_id = subscription.interest_in

        # item_id is of the form ":state/:session/:chamber/:bill_id" (URI encoded already)
        url = "#{endpoint}/bills/#{URI.encode item_id.gsub('__', '/').gsub('_', ' ')}/?apikey=#{api_key}"
        url << "&fields=#{fields.join ','}"

        url
      end

      def self.search_name(subscription)
        "Official Activity"
      end

      def self.item_name(subscription)
        "State bill activity"
      end

      def self.short_name(number, interest)
        number == 1 ? 'action' : 'actions'
      end

      def self.direct_item_url(action, interest)
        url = Subscriptions::Adapters::StateBills.openstates_url(interest.data)
        "#{url}#actions"
      end

      def self.items_for(response, function, options = {})
        return nil unless response['actions']

        actions = []
        response['actions'].each do |action|
          actions << item_for(response['id'], action)
        end
        actions
      end


      # private

      def self.item_for(bill_id, action)
        return nil unless action

        action['date'] = Time.zone.parse action['date']

        SeenItem.new(
          item_id: "#{bill_id}-action-#{action['date'].to_i}",
          date: action['date'],
          data: action
        )
      end

    end

  end
end
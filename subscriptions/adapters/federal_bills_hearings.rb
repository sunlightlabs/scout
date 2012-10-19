module Subscriptions  
  module Adapters

    class FederalBillsHearings
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint].dup
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ chamber session committee occurs_at description room hearing_url hearing_type subcommittee_name }

        bill_id = subscription.interest_in
        
        url = "#{endpoint}/committee_hearings.json?apikey=#{api_key}"
        url << "&bill_ids=#{bill_id}"
        url << "&dc=true"
        url << "&committee__exists=true"

        # re-initialize after making this change
        # if function == :search 
          url << "&occurs_at__gte=#{Time.now.midnight.utc.xmlschema}"
        # end
        
        url << "&sections=#{sections.join ','}"
        
        url
      end

      def self.search_name(subscription)
        "Upcoming Hearings"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "hearings" : "hearing"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['committee_hearings']
        
        response['committee_hearings'].map do |hearing|
          item_for hearing
        end
      end
      
      
      def self.item_for(hearing)
        return nil unless hearing

        hearing['occurs_at'] = Time.zone.parse(hearing['occurs_at']).utc

        SeenItem.new(
          :item_id => "#{hearing['chamber']}-#{hearing['occurs_at'].to_i}",
          :date => hearing['occurs_at'],
          :data => hearing
        )
      end
      
    end
  
  end
end
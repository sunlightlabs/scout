module Subscriptions  
  module Adapters

    class CommitteeHearings
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ basic committee.name }
        per_page = (function == :search) ? 20 : 40
        
        url = "#{endpoint}/committee_hearings.json?apikey=#{api_key}"
        url << "&per_page=#{per_page}"
        url << "&search=#{query}"
        url << "&order=occurs_at"
        url << "&sections=#{sections.join ','}"
        url << "&chamber=senate"

        if options[:page]
          url << "&page=#{options[:page]}"
        end
        
        url
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['committee_hearings']
        
        response['committee_hearings'].map do |hearing|
          item_for hearing
        end
      end
      
      
      
      # internal
      
      def self.item_for(hearing)
        hearing['legislative_day'] = noon_utc_for hearing['legislative_day']

        id = "#{hearing['committee_id']}-#{hearing['occurs_at'].utc.xmlschema}"

        SeenItem.new(
          :item_id => id,
          :date => hearing['occurs_at'],
          :data => hearing
        )
          
      end
      
      # helper function to straighten dates into UTC times (necessary for serializing to BSON, sigh)
      def self.noon_utc_for(date)
        time = date.to_time
        time.getutc + (12-time.getutc.hour).hours
      end
      
    end
  
  end
end
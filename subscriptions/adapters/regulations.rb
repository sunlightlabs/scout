module Subscriptions  
  module Adapters

    class Regulations
      
      MAX_ITEMS = 40
      
      # non-destructive, searches for example results
      def self.search(subscription)
        Subscriptions::Manager.poll subscription, :search
      end
      
      # ignore function, all polls look for the same information
      def self.url_for(subscription, function)
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ stage title abstract document_number rins docket_ids published_at effective_at federal_register_url agency_names agency_ids }
        
        url = "#{endpoint}/search/regulations.json?apikey=#{api_key}"
        url << "&per_page=#{MAX_ITEMS}"
        url << "&query=#{query}"
        url << "&order=published_at"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true"
        url << "&highlight_size=500"
        url << "&highlight_tags=,"

        url
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function)
        return nil unless response['regulations']
        
        response['regulations'].map do |regulation|
          item_for regulation
        end
      end
      
      
      
      # internal
      
      def self.item_for(regulation)
        Subscriptions::Result.new(
          :id => regulation["document_number"],
          :date => regulation["published_at"],
          :data => regulation
        )
          
      end

    end
  
  end
end
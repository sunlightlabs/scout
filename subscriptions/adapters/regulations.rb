module Subscriptions  
  module Adapters

    class Regulations
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.interest_in
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ stage title abstract document_number rins docket_ids published_at effective_at federal_register_url agency_names agency_ids }
        
        per_page = (function == :search) ? 20 : 40

        url = "#{endpoint}/search/regulations.json?apikey=#{api_key}"
        url << "&per_page=#{per_page}"
        url << "&query=#{query}"
        url << "&order=published_at"
        url << "&sections=#{sections.join ','}"
        url << "&highlight=true"
        url << "&highlight_size=500"
        url << "&highlight_tags=,"

        if options[:page]
          url << "&page=#{options[:page]}"
        end

        url
      end

      def self.description(number, subscription, interest)
        "#{number} proposed or final #{number > 1 ? "regulations" : "regulation"}"
      end

      def self.short_name(number, subscription, interest)
        "#{number > 1 ? "regulations" : "regulation"}"
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['regulations']
        
        response['regulations'].map do |regulation|
          item_for regulation
        end
      end
      
      
      
      # internal
      
      def self.item_for(regulation)
        
        SeenItem.new(
          :item_id => regulation["document_number"],
          :date => regulation["published_at"],
          :data => regulation
        )
          
      end

    end
  
  end
end
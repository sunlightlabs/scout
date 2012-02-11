module Subscriptions  
  module Adapters

    class GaoReports
      
      MAX_ITEMS = 20
      
      def self.search(subscription, options = {})
        Subscriptions::Manager.poll subscription, :search, options
      end
      
      def self.url_for(subscription, function, options = {})
        api_key = config[:subscriptions][:sunlight_api_key]
        query = URI.escape subscription.keyword
        
        if config[:subscriptions][:rtc_endpoint].present?
          endpoint = config[:subscriptions][:rtc_endpoint]
        else
          endpoint = "http://api.realtimecongress.org/api/v1"
        end
        
        sections = %w{ basic gao_id pdf_url }
        
        url = "#{endpoint}/documents.json?apikey=#{api_key}"
        url << "&per_page=#{MAX_ITEMS}"
        url << "&search=#{query}"
        url << "&order=posted_at"
        url << "&sections=#{sections.join ','}"
        url << "&document_type=gao_report"

        if options[:page]
          url << "&page=#{options[:page]}"
        end
        
        url
      end
      
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        return nil unless response['documents']
        
        response['documents'].map do |report|
          item_for report
        end
      end
      
      
      
      # internal
      
      def self.item_for(report)
        Subscriptions::Result.new(
          :id => report['gao_id'],
          :date => report['posted_at'],
          :data => report
        )
          
      end
      
    end
  
  end
end
module Subscriptions  
  module Adapters

    class Regulations

      def self.filters
        {
          "agency" => {
            field: "agency_ids",
            name: -> id {executive_agency_abbreviations[executive_agency_map[id]] || executive_agency_map[id]}
          },
          "stage" => {
            name: -> stage {"#{stage.capitalize} Rule"}
          }
        }
      end
      
      def self.url_for(subscription, function, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]
        
        if config[:subscriptions][:congress_endpoint].present?
          endpoint = config[:subscriptions][:congress_endpoint].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end
        
        fields = %w{ 
          document_number document_type article_type
          stage title abstract 
          posted_at publication_date
          url agency_names agency_ids 
        }

        url = endpoint

        query = subscription.query['query']
        if query.present?
          url << "/regulations/search?"
          url << "&query=#{CGI.escape query}"

          url << "&highlight=true"
          url << "&highlight.size=500"
          url << "&highlight.tags=,"
        else
          url << "/regulations?"
        end

        if subscription.query['citations'].any?
          citations = subscription.query['citations'].map {|c| c['citation_id']}
          url << "&citing=#{citations.join "|"}"
          url << "&citing.details=true"
        end

        url << "&order=posted_at"
        url << "&fields=#{fields.join ','}"
        url << "&apikey=#{api_key}"

        # filters

        ["agency", "stage"].each do |field|
          if subscription.data[field].present?
            url << "&#{filters[field][:field] || field}=#{CGI.escape subscription.data[field]}"
          end
        end

        # if it's background checking, filter to just the last month for speed
        if function == :check
          url << "&posted_at__gte=#{1.month.ago.strftime "%Y-%m-%d"}"
        end


        url << "&page=#{options[:page]}" if options[:page]
        per_page = (function == :search) ? (options[:per_page] || 20) : 40
        url << "&per_page=#{per_page}"

        url
      end

      def self.url_for_detail(item_id, options = {})
        api_key = options[:api_key] || config[:subscriptions][:sunlight_api_key]

        if config[:subscriptions][:congress_endpoint].present?
          endpoint = config[:subscriptions][:congress_endpoint].dup
        else
          endpoint = "http://congress.api.sunlightfoundation.com"
        end
        
        fields = %w{ 
          stage title abstract article_type
          document_number document_type 
          posted_at publication_date 
          url pdf_url 
          agency_names agency_ids
        }

        url = "#{endpoint}/regulations?apikey=#{api_key}"
        url << "&document_number=#{item_id}"
        url << "&fields=#{fields.join ','}"

        url
      end

      def self.interest_title(interest)
        interest.data['title']
      end

      def self.search_name(subscription)
        "Federal Regulations"
      end

      def self.short_name(number, interest)
        "#{number > 1 ? "regulations" : "regulation"}"
      end
      
      # takes parsed response and returns an array where each item is 
      # a hash containing the id, title, and post date of each item found
      def self.items_for(response, function, options = {})
        raise AdapterParseException.new("Response didn't include results field: #{response.inspect}") unless response['results']
        
        response['results'].map do |regulation|
          item_for regulation
        end
      end

      def self.item_detail_for(response)
        item_for response['results'][0]
      end
      
      
      
      # internal
      
      def self.item_for(regulation)
        return nil unless regulation

        SeenItem.new(
          item_id: regulation["document_number"],
          date: regulation["posted_at"],
          data: regulation
        )
          
      end

      # utility function for mapping agencies
      # all the agencies that appear in regulations going back to 2009
      # should probably get automated and moved into a database somewhere
      def self.executive_agency_map
        @executive_agency_map ||= {
          "6" => "Agency for International Development",
          "9" => "Agricultural Marketing Service",
          "10" => "Agricultural Research Service",
          "12" => "Agriculture Department",
          "13" => "Air Force Department",
          "18" => "Alcohol and Tobacco Tax and Trade Bureau",
          "19" => "Alcohol, Tobacco, Firearms, and Explosives Bureau",
          "22" => "Animal and Plant Health Inspection Service",
          "28" => "Architectural and Transportation Barriers Compliance Board",
          "30" => "Armed Forces Retirement Home",
          "32" => "Army Department",
          "39" => "Board of Directors of the Hope for Homeowners Program",
          "41" => "Broadcasting Board of Governors",
          "42" => "Census Bureau",
          "44" => "Centers for Disease Control and Prevention",
          "45" => "Centers for Medicare & Medicaid Services",
          "46" => "Central Intelligence Agency",
          "47" => "Chemical Safety and Hazard Investigation Board",
          "48" => "Child Support Enforcement Office",
          "49" => "Children and Families Administration",
          "53" => "Coast Guard",
          "54" => "Commerce Department",
          "76" => "Commodity Credit Corporation",
          "77" => "Commodity Futures Trading Commission",
          "78" => "Community Development Financial Institutions Fund",
          "80" => "Comptroller of the Currency",
          "84" => "Consumer Product Safety Commission",
          "85" => "Cooperative State Research, Education, and Extension Service",
          "87" => "Copyright Office, Library of Congress",
          "88" => "Copyright Royalty Board",
          "91" => "Corporation for National and Community Service",
          "92" => "Council on Environmental Quality",
          "94" => "Court Services and Offender Supervision Agency for the District of Columbia",
          "96" => "Customs Service",
          "97" => "Defense Acquisition Regulations System",
          "103" => "Defense Department",
          "109" => "Defense Nuclear Facilities Safety Board",
          "112" => "Delaware River Basin Commission",
          "116" => "Drug Enforcement Administration",
          "118" => "Economic Analysis Bureau",
          "120" => "Economic Development Administration",
          "126" => "Education Department",
          "127" => "Election Assistance Commission",
          "131" => "Employee Benefits Security Administration",
          "133" => "Employment and Training Administration",
          "134" => "Employment Standards Administration",
          "136" => "Energy Department",
          "137" => "Energy Efficiency and Renewable Energy Office",
          "142" => "Engineers Corps",
          "145" => "Environmental Protection Agency",
          "147" => "Equal Employment Opportunity Commission",
          "149" => "Executive Office for Immigration Review",
          "151" => "Export-Import Bank",
          "154" => "Farm Credit Administration",
          "156" => "Farm Credit System Insurance Corporation",
          "157" => "Farm Service Agency",
          "159" => "Federal Aviation Administration",
          "161" => "Federal Communications Commission",
          "162" => "Federal Contract Compliance Programs Office",
          "163" => "Federal Crop Insurance Corporation",
          "164" => "Federal Deposit Insurance Corporation",
          "165" => "Federal Election Commission",
          "166" => "Federal Emergency Management Agency",
          "167" => "Federal Energy Regulatory Commission",
          "168" => "Federal Financial Institutions Examination Council",
          "170" => "Federal Highway Administration",
          "173" => "Federal Housing Enterprise Oversight Office",
          "174" => "Federal Housing Finance Agency",
          "175" => "Federal Housing Finance Board",
          "176" => "Federal Labor Relations Authority",
          "178" => "Federal Maritime Commission",
          "179" => "Federal Mediation and Conciliation Service",
          "180" => "Federal Mine Safety and Health Review Commission",
          "181" => "Federal Motor Carrier Safety Administration",
          "184" => "Federal Procurement Policy Office",
          "185" => "Federal Railroad Administration",
          "186" => "Federal Register Office",
          "187" => "Federal Register, Administrative Committee",
          "188" => "Federal Reserve System",
          "189" => "Federal Retirement Thrift Investment Board",
          "192" => "Federal Trade Commission",
          "193" => "Federal Transit Administration",
          "194" => "Financial Crimes Enforcement Network",
          "196" => "Fiscal Service",
          "197" => "Fish and Wildlife Service",
          "199" => "Food and Drug Administration",
          "200" => "Food and Nutrition Service",
          "201" => "Food Safety and Inspection Service",
          "202" => "Foreign Agricultural Service",
          "203" => "Foreign Assets Control Office",
          "208" => "Foreign-Trade Zones Board",
          "209" => "Forest Service",
          "210" => "General Services Administration",
          "213" => "Government Accountability Office",
          "215" => "Government Ethics Office",
          "218" => "Grain Inspection, Packers and Stockyards Administration",
          "221" => "Health and Human Services Department",
          "222" => "Health Resources and Services Administration",
          "227" => "Homeland Security Department",
          "228" => "Housing and Urban Development Department",
          "234" => "Indian Affairs Bureau",
          "237" => "Indian Health Service",
          "241" => "Industry and Security Bureau",
          "243" => "Information Security Oversight Office",
          "253" => "Interior Department",
          "254" => "Internal Revenue Service",
          "261" => "International Trade Administration",
          "262" => "International Trade Commission",
          "265" => "Joint Board for Enrollment of Actuaries",
          "268" => "Justice Department",
          "269" => "Justice Programs Office",
          "271" => "Labor Department",
          "274" => "Labor-Management Standards Office",
          "275" => "Land Management Bureau",
          "276" => "Legal Services Corporation",
          "277" => "Library of Congress",
          "280" => "Management and Budget Office",
          "282" => "Maritime Administration",
          "285" => "Merit Systems Protection Board",
          "288" => "Mine Safety and Health Administration",
          "289" => "Minerals Management Service",
          "301" => "National Aeronautics and Space Administration",
          "304" => "National Archives and Records Administration",
          "335" => "National Credit Union Administration",
          "342" => "National Foundation on the Arts and the Humanities",
          "344" => "National Geospatial-Intelligence Agency",
          "345" => "National Highway Traffic Safety Administration",
          "347" => "National Indian Gaming Commission",
          "350" => "National Institute of Food and Agriculture",
          "352" => "National Institute of Standards and Technology",
          "353" => "National Institutes of Health",
          "354" => "National Intelligence, Office of the National Director",
          "355" => "National Labor Relations Board",
          "357" => "National Mediation Board",
          "361" => "National Oceanic and Atmospheric Administration",
          "362" => "National Park Service",
          "366" => "National Science Foundation",
          "373" => "National Telecommunications and Information Administration",
          "374" => "National Transportation Safety Board",
          "376" => "Natural Resources Conservation Service",
          "378" => "Navy Department",
          "383" => "Nuclear Regulatory Commission",
          "386" => "Occupational Safety and Health Administration",
          "387" => "Occupational Safety and Health Review Commission",
          "401" => "Parole Commission",
          "402" => "Patent and Trademark Office",
          "405" => "Pension Benefit Guaranty Corporation",
          "406" => "Personnel Management Office",
          "408" => "Pipeline and Hazardous Materials Safety Administration",
          "409" => "Postal Regulatory Commission",
          "410" => "Postal Service",
          "436" => "Presidio Trust",
          "437" => "Prisons Bureau",
          "444" => "Railroad Retirement Board",
          "447" => "Recovery Accountability and Transparency Board",
          "449" => "Regulatory Information Service Center",
          "456" => "Rural Business-Cooperative Service",
          "458" => "Rural Housing Service",
          "460" => "Rural Utilities Service",
          "462" => "Saint Lawrence Seaway Development Corporation",
          "466" => "Securities and Exchange Commission",
          "468" => "Small Business Administration",
          "470" => "Social Security Administration",
          "474" => "Special Inspector General For Iraq Reconstruction",
          "476" => "State Department",
          "480" => "Surface Mining Reclamation and Enforcement Office",
          "481" => "Surface Transportation Board",
          "482" => "Susquehanna River Basin Commission",
          "486" => "Tennessee Valley Authority",
          "489" => "Thrift Supervision Office",
          "492" => "Transportation Department",
          "494" => "Transportation Security Administration",
          "497" => "Treasury Department",
          "499" => "U.S. Citizenship and Immigration Services",
          "501" => "U.S. Customs and Border Protection",
          "503" => "U.S. Immigration and Customs Enforcement",
          "520" => "Veterans Affairs Department",
          "521" => "Veterans Employment and Training Service",
          "524" => "Wage and Hour Division",
          "565" => "Financial Stability Oversight Council",
          "566" => "Administrative Conference of the United States",
          "568" => "Ocean Energy Management, Regulation, and Enforcement Bureau",
          "573" => "Consumer Financial Protection Bureau",
          "574" => "Financial Research Office",
          "576" => "Safety and Environmental Enforcement Bureau",
          "579" => "Special Inspector General for Afghanistan Reconstruction",
          "581" => "Advocacy and Outreach Office",
        }
      end

      def self.executive_agency_abbreviations
        @executive_agency_abbreviations ||= {
          "Federal Communications Commission" => "FCC",
          "Federal Election Commission" => "FEC",
          "Federal Emergency Management Agency" => "FEMA"
        }
      end

    end
  
  end
end
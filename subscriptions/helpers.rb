module Subscriptions
  module Helpers

    def bill_code(type, number)
      "#{bill_type type} #{number}"
    end

    def bill_fields_from(bill_id)
      type = bill_id.gsub /[^a-z]/, ''
      number = bill_id.match(/[a-z]+(\d+)-/)[1].to_i
      session = bill_id.match(/-(\d+)$/)[1].to_i
      
      code = "#{type}#{number}"
      chamber = {'h' => 'house', 's' => 'senate'}[type.first.downcase]
      
      [type, number, session, code, chamber]
    end
    
    # standardized in accordance with http://www.gpoaccess.gov/bills/glossary.html
    def bill_type(short)
      {
        "hr" => "H.R.",
        "hres" => "H.Res.",
        "hjres" => "H.J.Res.",
        "hcres" => "H.Con.Res.",
        "s" => "S.",
        "sres" => "S.Res.",
        "sjres" => "S.J.Res.",
        "scres" => "S.Con.Res."
      }[short]
    end
    
    def fulltext_highlight(item, keyword, priorities, highlight = true)
      highlighting = item.data['search']['highlight']
      field = highlighting.keys.sort_by {|k| priorities[k]}.first
      excerpt highlighting[field].first, keyword, highlight
    end

    def bill_highlight(item, keyword, highlight = true)
      fulltext_highlight item, keyword, bill_priorities, highlight
    end

    def regulation_highlight(item, keyword, highlight = true)
      fulltext_highlight item, keyword, regulation_priorities, highlight
    end

    def agency_names(regulation)
      regulation['agency_names'].uniq.join ", "
    end
    
    def govtrack_type(bill_type)
      {
        "hr" => "h",
        "hres" => "hr",
        "hjres" => "hj",
        "hcres" => "hc",
        "s" => "s",
        "sres" => "sr",
        "sjres" => "sj",
        "scres" => "sc"
      }[bill_type]
    end
    
    # most are fine, just alter the con res's
    def thomas_type(bill_type)
      {
        "hcres" => "hconres",
        "scres" => "sconres"
      }[bill_type] || bill_type
    end
    
    def opencongress_url(item)
      bill = item.data
      id = "#{bill['session']}-#{govtrack_type bill['bill_type']}#{bill['number']}"
      "http://www.opencongress.org/bill/#{id}/show"
    end
    
    def govtrack_url(item)
      bill = item.data
      id = "#{govtrack_type bill['bill_type']}#{bill['session']}-#{bill['number']}"
      "http://www.govtrack.us/congress/bill.xpd?bill=#{id}"
    end
    
    def thomas_url(item)
      bill = item.data
      id = "#{bill['session']}#{thomas_type bill['bill_type']}#{bill['number']}"
      "http://hdl.loc.gov/loc.uscongress/legislation.#{id}"
    end

    # unused    
    def highlight_field(field)
      {
        "versions" => "the full text",
        "summary" => "the CRS summary",
        "official_title" => "the official title",
        "short_title" => "the shorthand title",
        "popular_title" => "the common parlance",
        "keywords" => "the tagged subjects"
      }[field]
    end
    
    def bill_priorities
      {
        "summary" => 1,
        "versions" => 2,
        "keywords" => 3,
        "official_title" => 4,
        "short_title" => 5,
        "popular_title" => 6
      }
    end

    def regulation_priorities
      {
        'abstract' => 1,
        'full_text' => 2,
        'title' => 3
      }
    end
    
    # adapted from http://www.gpoaccess.gov/bills/glossary.html
    def bill_version(code)
      {
        'ash' => "Additional Sponsors House",
        'ath' => "Agreed to House",
        'ats' => "Agreed to Senate",
        'cdh' => "Committee Discharged House",
        'cds' => "Committee Discharged Senate",
        'cph' => "Considered and Passed House",
        'cps' => "Considered and Passed Senate",
        'eah' => "Engrossed Amendment House",
        'eas' => "Engrossed Amendment Senate",
        'eh' => "Engrossed in House",
        'ehr' => "Engrossed in House-Reprint",
        'eh_s' => "Engrossed in House (No.) Star Print [*]",
        'enr' => "Enrolled Bill",
        'es' => "Engrossed in Senate",
        'esr' => "Engrossed in Senate-Reprint",
        'es_s' => "Engrossed in Senate (No.) Star Print",
        'fah' => "Failed Amendment House",
        'fps' => "Failed Passage Senate",
        'hdh' => "Held at Desk House",
        'hds' => "Held at Desk Senate",
        'ih' => "Introduced in House",
        'ihr' => "Introduced in House-Reprint",
        'ih_s' => "Introduced in House (No.) Star Print",
        'iph' => "Indefinitely Postponed in House",
        'ips' => "Indefinitely Postponed in Senate",
        'is' => "Introduced in Senate",
        'isr' => "Introduced in Senate-Reprint",
        'is_s' => "Introduced in Senate (No.) Star Print",
        'lth' => "Laid on Table in House",
        'lts' => "Laid on Table in Senate",
        'oph' => "Ordered to be Printed House",
        'ops' => "Ordered to be Printed Senate",
        'pch' => "Placed on Calendar House",
        'pcs' => "Placed on Calendar Senate",
        'pp' => "Public Print",
        'rah' => "Referred w/Amendments House",
        'ras' => "Referred w/Amendments Senate",
        'rch' => "Reference Change House",
        'rcs' => "Reference Change Senate",
        'rdh' => "Received in House",
        'rds' => "Received in Senate",
        're' => "Reprint of an Amendment",
        'reah' => "Re-engrossed Amendment House",
        'renr' => "Re-enrolled",
        'res' => "Re-engrossed Amendment Senate",
        'rfh' => "Referred in House",
        'rfhr' => "Referred in House-Reprint",
        'rfh_s' => "Referred in House (No.) Star Print",
        'rfs' => "Referred in Senate",
        'rfsr' => "Referred in Senate-Reprint",
        'rfs_s' => "Referred in Senate (No.) Star Print",
        'rh' => "Reported in House",
        'rhr' => "Reported in House-Reprint",
        'rh_s' => "Reported in House (No.) Star Print",
        'rih' => "Referral Instructions House",
        'ris' => "Referral Instructions Senate",
        'rs' => "Reported in Senate",
        'rsr' => "Reported in Senate-Reprint",
        'rs_s' => "Reported in Senate (No.) Star Print",
        'rth' => "Referred to Committee House",
        'rts' => "Referred to Committee Senate",
        'sas' => "Additional Sponsors Senate",
        'sc' => "Sponsor Change House",
        's_p' => "Star (No.) Print of an Amendment"
      }[code]
    end
    
    def state_name(code)
      state_map[code.to_s.upcase]
    end

    def state_map
      @state_map ||= ScoutUtils.state_map
    end
    
    def state_version_info?(bill)
      bill['versions'] and bill['versions'].any?
    end
    
    def state_source_info?(bill)
      bill['sources'] and bill['sources'].any?
    end
    
    def speech_selection(speech, keyword)
      first = speech['speaking'].select do |paragraph|
        paragraph =~ excerpt_pattern(keyword)
      end.first
    end

    def speech_excerpt(speech, keyword, highlight = true)
      if selection = speech_selection(speech, keyword)
        excerpt selection, keyword, highlight
      end
    end

    def excerpt_pattern(keyword)
      /#{keyword.gsub(' ', '[\s\-]')}/i
    end
    
    # client-side truncation and highlighting
    def excerpt(text, keyword, highlight = true)

      text = text.strip
      word = keyword.size
      length = text.size
      
      index = text =~ excerpt_pattern(keyword) || 0
      max = 500
      buffer = 100

      range = nil
      if (length < max) || ((index + word) < (max - buffer))
        range = 0..max
      else
        finish = nil
        if (index + word + buffer) < length
          finish = index + word + buffer
        else
          finish = length
        end
        start = finish - max
        range = start..finish
      end

      truncated = text[range]
      truncated = "..." + truncated if (range.begin > 0) || (text[0..0].upcase != text[0..0])
      truncated = truncated + "..." if range.end < length

      if highlight
        truncated.gsub(excerpt_pattern(keyword)) do |word|
          "<em>#{word}</em>"
        end
      else
        truncated
      end
    end

    def truncate(string, length)
      if string.size > (length + 3)
        string[0...length] + "..."
      else
        string
      end
    end
    
    def speaker_name(speech)
      party = speech['speaker_party']
      state = speech['speaker_state']
      "#{speaker_name_only speech} (#{party}-#{state})"
    end

    def speaker_party(party)
      {
        "R" => "Republican",
        "D" => "Democrat",
        "I" => "Independent"
      }[party]
    end

    def speaker_name_only(speech)
      title = (speech['chamber'] == 'Senate') ? 'Sen' : 'Rep'
      "#{title}. #{speech['speaker_first']} #{speech['speaker_last']}"
    end

    def legislator_name(legislator)
      titled_name = "#{legislator['title']}. #{(legislator['nickname'].to_s != "") ? legislator['nickname'] : legislator['first_name']} #{legislator['last_name']}"
      "#{titled_name} [#{legislator['party']}-#{legislator['state']}]"
    end

    def bill_summary(bill)
      summary = bill['summary'].dup
      summary.sub! /^\d+\/\d+\/\d+--.+?\.\s*/, ""
      summary.sub! /(\(This measure.+?\))\n*\s*/, ""
      if bill['short_title']
        summary.sub! /^#{bill['short_title']} - /, ""
      end
      summary
    end

    def legislator_image(legislator)
      "http://assets.sunlightfoundation.com/moc/40x50/#{legislator['bioguide_id']}.jpg"
    end
    
    def speaker_url(speech)
      "http://capitolwords.org/legislator/#{speech['bioguide_id']}"
    end

    def regulation_stage(stage)
      {
        :proposed => "Proposed Rule",
        :final => "Final Rule"
      }[stage.to_sym] || "Rule"
    end

    def opengovernment_url(bill)
      state = bill['state'].to_s.downcase
      bill_id = bill['bill_id'].downcase.gsub(' ', '-')
      session = bill['session']
      
      "http://#{state}.opengovernment.org/sessions/#{session}/bills/#{bill_id}"
    end

    def state_in_og?(code)
      ["CA", "LA", "MD", "MN", "TX"].include? code.to_s.upcase
    end

    def state_vote_count(vote)
      "#{vote['passed'] ? "Passed" : "Not Passed"}, #{vote['yes_count']}-#{vote['no_count']}-#{vote['other_count']}"
    end

    def state_vote_type(vote)
      type = ""
      if vote['committee'] or vote['motion'] =~ /committee/i
        type = "Committee "
      end
      "#{type}#{vote['type'].capitalize}"
    end

    # all the agencies that appear in regulations going back to 2009
    # should probably get automated and moved into a database somewhere
    def executive_agency_map
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

  end
end
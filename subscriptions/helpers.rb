module Helpers
  module Subscriptions

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
    
    def regulation_title(regulation)
      regulation['title'].present? ? regulation['title'] : "(No published title yet)"
    end

    def agency_names(regulation)
      regulation['agency_names'].uniq.join ", "
    end

    def preferred_field(item, priorities)
      highlighting = item.data['search']['highlight']
      valid_keys = priorities.keys & highlighting.keys
      return nil unless valid_keys.any?
      valid_keys.sort_by {|k| priorities[k]}.first
    end


    def bill_highlight(item, interest, options = {})
      keywords = keywords_from interest

      if item.data['citations'] and item.data['citations'].any?
        matches = item.data['citations'].map {|c| c['match']}
        cite = item.data['citations'].first
        excerpt cite['excerpt'], (keywords + matches), options
      elsif item.data['search'] and item.data['search']['highlight']
        field = preferred_field item, bill_priorities
        return nil unless field

        text = item.data['search']['highlight'][field].first

        if field == "keywords"
          text = "Official keyword: \"#{text}\""
        end
        
        excerpt text, keywords, options
      end
    end

    def regulation_highlight(item, interest, options = {})
      keywords = keywords_from interest

      if item.data['citations'] and item.data['citations'].any?
        matches = item.data['citations'].map {|c| c['match']}
        cite = item.data['citations'].first
        excerpt cite['excerpt'], (keywords + matches), options
      elsif item.data['search'] and item.data['search']['highlight']
        field = preferred_field item, regulation_priorities
        return nil unless field
        text = item.data['search']['highlight'][field].first
        
        excerpt text, keywords, options
      end
    end

    def document_highlight(item, interest, options = {})
      keywords = keywords_from interest

      if item.data['citations'] and item.data['citations'].any?
        matches = item.data['citations'].map {|c| c['match']}
        cite = item.data['citations'].first
        excerpt cite['excerpt'], (keywords + matches), options
      elsif item.data['search'] and item.data['search']['highlight']
        field = preferred_field item, document_priorities
        return nil unless field
        text = item.data['search']['highlight'][field].first
        
        if field == "categories"
          text = "Official category: \"#{text}\""
        end

        excerpt text, keywords, options
      end
    end

    def state_bill_highlight(item, interest, options = {})
      keywords = keywords_from interest
      title = item.data['+short_title'] || item.data['title']
      excerpt = excerpt title, keywords, options
      excerpt || title
    end

    def speech_excerpt(speech, interest, options = {})
      keywords = keywords_from interest
      text = speech['speaking'].join("\n\n")
      excerpt = excerpt text, keywords, options
      excerpt || truncate(text, 500)
    end


    # can be given one or more terms to match
    def excerpt_pattern(keywords)
      keywords = [keywords] unless keywords.is_a?(Array)
      patterns = keywords.map {|keyword| keyword.gsub('"', '').gsub(' ', '[\s\-]').gsub('(', '\(').gsub(')', '\)')}
      /(#{patterns.join "|"})/i
    end

    def keywords_from(interest)
      if interest.query['advanced']
        keywords = []

        interest.query['advanced']['included'].each do |term|
          keywords << term['term'].to_s.tr("*", "")
        end

        interest.query['advanced']['distance'].each do |distance|
          keywords += distance['words'] # just words, not phrases or citations
        end

        keywords
      else # simple search, or unparsed advanced search
        [interest.in]
      end
    end
    
    # client-side truncation and highlighting
    def excerpt(text, keywords, options = {})
      options[:highlight] = true unless options.has_key?(:highlight)

      keywords = [keywords] unless keywords.is_a?(Array) # wrap single string in an array

      text = text.strip
      text.gsub! "\f", "" # I have seen these, and do not know why

      # find the first mention of a term in the excerpt, center the excerpting around it
      matched_keyword = nil
      index = 0
      keywords.each do |keyword|
        if match = (text =~ excerpt_pattern(keyword))
          index = match
          matched_keyword = keyword
          break
        end
      end
      
      # maximum size of the excerpt
      max = options[:max] || 500

      # minimum room to leave after the term
      buffer = 100 

      word = matched_keyword ? matched_keyword.size : 0
      length = text.size

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
      truncated = "..." + truncated if options[:ellipses] || (range.begin > 0) || (text[0..0].upcase != text[0..0])
      truncated = truncated + "..." if options[:ellipses] || range.end < length

      if options[:highlight]
        if options[:highlight_tags]
          tag1, tag2 = options[:highlight_tags]
        elsif options[:inline]
          tag1, tag2 = ["<em style=\"font-weight: bold; font-style: normal; color: #13B326\">", "</em>"]
        else
          tag1, tag2 = ["<em>", "</em>"]
        end

        truncated.gsub(excerpt_pattern(keywords)) do |word|
          "#{tag1}#{word}#{tag2}"
        end
      else
        truncated
      end
    end

    # for excerpting advanced searches with multiple terms,
    # try to produce excerpts that show each term used at least once
    # 
    # texts: array of excerpts
    # terms: array of term hashes as returned from the Search model
    # options: options hash to be passed directly to underlying excerpt function
    # def excerpt_advanced(texts, terms, options = {})
    #   term_strings = terms.map do |term|
    #     # todo: this is where we could strip asterisks off of fuzzy terms
    #     term['phrase'].to_s
    #   end
    #   matched_strings = []
    #   results = []

    #   # go over each excerpt until we've got at least one excerpt for each term
    #   texts.each do |text|
    #     next if (term_strings - matched_strings).empty?

    #     term_strings.each do |keyword|
    #       next if matched_strings.include?(keyword) # only need one match

    #       if result = excerpt(text, keyword, options.merge(require_match: true))
    #         results << result
    #         matched_strings << keyword
    #       end
    #     end
    #   end

    #   if results.any?
    #     results
    #   else
    #     truncate texts.first, (options[:max] || 500)
    #   end
    # end

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

    def congress_gov_type(bill_type)
      {
        "hr" => "house-bill",
        "hres" => "house-resolution",
        "hcres" => "house-concurrent-resolution",
        "hjres" => "house-joint-resolution",
        "s" => "senate-bill",
        "sres" => "senate-resolution",
        "scres" => "senate-concurrent-resolution",
        "sjres" => "senate-joint-resolution"
      }[bill_type]
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

    def congress_gov_url(item)
      bill = item.data
      type = congress_gov_type bill['bill_type']
      # todo: when they expand to earlier (or later) congresses, 'th' is not a universal ordinal
      "http://beta.congress.gov/bill/#{bill['session']}th/#{type}/#{bill['number']}"
    end
    
    def bill_priorities
      {
        "summary" => 1,
        "versions" => 2,
        "keywords" => 3
      }
    end

    def regulation_priorities
      {
        'abstract' => 1,
        'full_text' => 2
      }
    end

    def document_priorities
      {
        "description" => 1,
        "text" => 2,
        "categories" => 3
      }
    end
    
    # adapted from http://www.gpoaccess.gov/bills/glossary.html
    def bill_version(code)
      {
        'ash' => "Additional Sponsors House",
        'ath' => "Agreed to in House",
        'ats' => "Agreed to in Senate",
        'cdh' => "Committee Discharged House",
        'cds' => "Committee Discharged Senate",
        'cph' => "Considered and Passed House",
        'cps' => "Considered and Passed Senate",
        'eah' => "Engrossed Amendment in House",
        'eas' => "Engrossed Amendment in Senate",
        'eh' => "Engrossed in House",
        'ehr' => "Engrossed in House-Reprint",
        'eh_s' => "Engrossed in House (No.) Star Print [*]",
        'enr' => "Enrolled Bill",
        'es' => "Engrossed in Senate",
        'esr' => "Engrossed in Senate-Reprint",
        'es_s' => "Engrossed in Senate (No.) Star Print",
        'fah' => "Failed Amendment in House",
        'fps' => "Failed Passage in Senate",
        'hdh' => "Held at Desk in House",
        'hds' => "Held at Desk in Senate",
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
        'oph' => "Ordered to be Printed in House",
        'ops' => "Ordered to be Printed in Senate",
        'pch' => "Placed on House Calendar", # original: "Placed on Calendar House"
        'pcs' => "Placed on Senate Calendar", # original: "Placed on SenateHouse"
        'pp' => "Public Print",
        'rah' => "Referred w/Amendments in House",
        'ras' => "Referred w/Amendments in Senate",
        'rch' => "Reference Change in House",
        'rcs' => "Reference Change in Senate",
        'rdh' => "Received in House",
        'rds' => "Received in Senate",
        're' => "Reprint of an Amendment",
        'reah' => "Re-engrossed Amendment in House",
        'renr' => "Re-enrolled",
        'res' => "Re-engrossed Amendment in Senate",
        'rfh' => "Referred in House",
        'rfhr' => "Referred in House-Reprint",
        'rfh_s' => "Referred in House (No.) Star Print",
        'rfs' => "Referred in Senate",
        'rfsr' => "Referred in Senate-Reprint",
        'rfs_s' => "Referred in Senate (No.) Star Print",
        'rh' => "Reported in House",
        'rhr' => "Reported in House-Reprint",
        'rh_s' => "Reported in House (No.) Star Print",
        'rih' => "Referral Instructions in House",
        'ris' => "Referral Instructions in Senate",
        'rs' => "Reported in Senate",
        'rsr' => "Reported in Senate-Reprint",
        'rs_s' => "Reported in Senate (No.) Star Print",
        'rth' => "Referred to Committee in House",
        'rts' => "Referred to Committee in Senate",
        'sas' => "Additional Sponsors in Senate",
        'sc' => "Sponsor Change in House",
        's_p' => "Star (No.) Print of an Amendment"
      }[code]
    end
    
    def state_name(code)
      state_map[code.to_s.upcase]
    end

    def state_map
      @state_map ||= ::Subscriptions::Adapters::StateBills.state_map
    end
    
    def state_version_info?(bill)
      bill['versions'] and bill['versions'].any?
    end
    
    def state_source_info?(bill)
      bill['sources'] and bill['sources'].any?
    end

    def speaker_name(speech)
      party = speech['speaker_party']
      state = speech['speaker_state']
      "#{speaker_name_only speech} (#{party}-#{state})"
    end

    def speaker_party(party)
      ::Subscriptions::Adapters::Speeches.party_map[party]
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
      return nil unless bill['summary'].present?

      summary = bill['summary'].dup
      summary.sub! /^\d+\/\d+\/\d+--.+?\.\s*/, ""
      summary.sub! /(\(This measure.+?\))\n*\s*/, ""

      if bill['short_title']
        summary.sub! /^#{bill['short_title']} - /, ""
      end

      post_truncate = lambda do |sum|
        # try to split up into meaningful paragraphs if possible
        sum.gsub(/\(Sec\.\s+\d+\)/) {|x| "\n\n<strong>#{x}</strong>"}
      end

      truncate_more_html "bill_summary", summary, 500, post_truncate
    end

    def state_bill_title(bill)
      return nil unless bill['title'].present? # shouldn't happen

      title = bill['title'].dup
      title.gsub! ';', ";\n\n"

      truncate_more_html "state_bill_title", title, 500
    end

    def regulation_abstract(regulation)
      return nil unless regulation['abstract'].present? # also checked in view

      truncate_more_html "regulation_abstract", regulation['abstract'], 1500
    end

    def speech_speaking(speech)
      speaking = speech['speaking'].join("\n\n")

      truncate_more_html "speech_speaking", speaking, 2000
    end

    def document_description(document)
      return nil unless document['description'] # shouldn't happen

      description = document['description']
      if document['document_type'] == "gao_report"
        ["What GAO Found", "Why GAO Did This Study"].each do |header|
          description = description.gsub /(#{header})/, '<strong>\1</strong>'
        end
      end

      truncate_more_html "document_description", description, 1500
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

    def openstates_url(bill)
      state = bill['state'].to_s.downcase
      bill_id = bill['bill_id'].tr(' ', '')
      session = bill['session']
      
      "http://openstates.org/#{state}/bills/#{session}/#{bill_id}"
    end

    def state_in_openstates?(code)
      states = %W{ 
        AK AZ CA DC DE FL HI ID IL LA MD MN MT NC NH NJ OH TX UT WI 
        AR CO IN IA KY MA MI NE NM OR PA PR RI TN VT VA
      }
      states.include? code.to_s.upcase
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

    def hearing_url(hearing)
      if hearing['chamber'] == 'senate'
        "http://www.senate.gov/pagelayout/committees/b_three_sections_with_teasers/committee_hearings.htm"
      else
        hearing['hearing_url']
      end
    end

    def vote_breakdown(vote)
      numbers = []
      total = vote['vote_breakdown']['total']
      numbers << total['Yea']
      numbers << total['Nay']
      # numbers << total['Present'] if total['Present']
      # numbers << total['Not Voting'] if total['Not Voting']
      numbers.join " - "
    end

    def vote_url(vote)
      if vote['chamber'] == "house"
        "http://clerk.house.gov/evs/#{vote['year']}/roll#{vote['number']}.xml"
      elsif vote['chamber'] == "senate"
        subsession = {0 => 2, 1 => 1}[vote['year'].to_i % 2]
        "http://www.senate.gov/legislative/LIS/roll_call_lists/roll_call_vote_cfm.cfm?congress=#{vote['session']}&session=#{subsession}&vote=#{zero_prefix_five vote['number']}"
      end
    end

  end
end
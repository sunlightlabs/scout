# encoding: utf-8


# collection of methods for processing search queries

class Search

  # run term through a gauntlet of citation checks
  def self.citation_for(term)
    if citation_id = usc_check(term)
      {
        'citation_id' => citation_id, 
        'citation_type' => 'usc',
        'original' => term # for adapters not supporting citations
      }
    else
      nil
    end
  end

  # Reads in a term and returns a US code citation ID compliant with citation.js
  # 
  # This obviously duplicates some of the functionality of citation.js, but is a convenient
  # beginning, and not all of what Scout looks for in searches will be what citation.js extracts.
  # also, citation.js (will eventually) use a whole lot more kinds of patterns and processing
  # strategies than are necessary for looking at search terms in Scout.
  # 
  # If this gets more complicated, we can have this call out to a citation-api 
  # instance in the future.

  # Checks the string to see if it *is* (not contains) a US Code citation.
  # If yes, returns the citation ID.
  # If not, returns nil.
  def self.usc_check(string)
    string = string.strip # for good measure
    section = subsections = title = nil

    if parts = string.scan(/^section (\d+[\w\d\-]*)((?:\([^\)]+\))*) (?:of|\,) title (\d+)$/i).first
      section = parts[0]
      subsections = parts[1].split(/[\)\(]+/).select &:present?
      title = parts[2]
    elsif parts = string.scan(/^(\d+)\s+U\.?\s?S\.?\s?C\.?[\s§]+(\d+[\w\d\-]*)((?:\([^\)]+\))*)$/i).first
      title = parts[0]
      section = parts[1]
      subsections = parts[2].split(/[\)\(]+/).select &:present?
    else
      return nil
    end

    [title, "usc", section, subsections].flatten.join "_"
  end

  def self.usc_standard(citation_id)
    title, usc, section, *subsections = citation_id.split "_"
    base = "#{title} USC § #{section}"
    base << "(#{subsections.join(")(")})" if subsections.any?
    base
  end


  # Simple search phrase parsing
  # 1) checks if phrase is a citation
  # 2) returns (0- or 1-element) array with found citations
  # 3) returns quoted phrase, or nil if phrase was citation
  def self.parse_simple(phrase)
    query = "\"#{phrase}\""
    if citation = citation_for(phrase)
      {'citations' => [citation]}
    else
      {'query' => query, 'citations' => []}
    end
  end

  # Advanced search query string parsing
  # 1) uses a Lucene query string parser library -
  # 2) yanks out any included terms which are citations, yanks out
  # 3) reserializes query string from parsed results
  def self.parse_advanced(query)
    
    # default to returning original query
    details = {'query' => query, 'citations' => []}

    begin
      parsed = LuceneQueryParser::Parser.new.parse query

    # if we can't parse it, it has to be okay, we can still pass the search on
    # so just return nil and let the caller decide how to handle it
    rescue Parslet::UnconsumedInput => e
      puts "Parse issue for [#{query}]: #{e.message}"
      return details
    rescue Exception => e
      puts "Unknown exception while parsing [#{query}]: #{e.class} - #{e.message}"
      return details
    end

    parsed = [parsed] unless parsed.is_a?(Array)
    
    citations = []

    included = []
    excluded = []
    distance = []

    parsed.each do |piece|
      if term = (piece[:term] or piece[:word] or piece[:phrase])
        term = term.to_s
        
        if piece[:prohibited]
          excluded << {'term' => term}

        elsif piece[:distance] and piece[:distance].to_s.to_i > 0
          # split term into words
          # (doesn't support distance between multi-word phrases)
          # (doesn't support citations)
          distance << {
            'words' => term.split(" "),
            'distance' => piece[:distance]
          }

        else
          if citation = citation_for(term)
            citations << citation
          else
            included << {'term' => term}
          end
        end

      end
    end

    details['citations'] = citations
    details['advanced'] = {
      'included' => included, 'excluded' => excluded, 'distance' => distance
    }

    # reconstruct the query from the parsed advanced search
    details['query'] = reserialize details['advanced']

    details
  end

  # take a parsed advanced query (with citations removed) and
  # turn it into a query string suitable for lucene
  # order should be deterministic no matter order of components
  def self.reserialize(advanced)
    quotify = -> str {str[" "] ? "\"#{str}\"" : str}

    query = ""
    query << " " + advanced['included'].map do |term| 
      quotify.call term['term']
    end.sort.join(" ")

    query << " " + advanced['distance'].map do |term|
      "\"#{term['words'].sort.join " "}\"~#{term['distance']}"
    end.sort.join(" ")
    
    query << " " + advanced['excluded'].map do |term|
      "-#{quotify.call term['term']}"
    end.sort.join(" ")

    query.strip
  end

  # produce a normalized string useful for deduping
  # takes in an interest's query hash as produced by parse_simple or parse_advanced
  def self.normalize(query)
    string = ""
    if query['citations'].any?
      # start with sorted citations, if any
      string << query['citations'].map do |cite|
        "#{cite['citation_type']}:#{cite['citation_id']}"
      end.sort.join(" ")
    end

    if query['query'].present?
      string << " " + query['query']
    end

    string.downcase.strip
  end

end
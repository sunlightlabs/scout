# encoding: utf-8


# collection of methods for processing search queries

class Search


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


  # Advanced search query string parsing, using a Lucene query string parser library

  def self.parse_advanced(query)
    begin
      parsed = LuceneQueryParser::Parser.new.parse query

    # if we can't parse it, it has to be okay, we can still pass the search on
    # so just return nil and let the caller decide how to handle it
    rescue Parslet::UnconsumedInput => e
      puts "Parse issue: #{e.message}"
      return nil
    rescue Exception => e
      puts "Unknown exception: #{e.type} - #{e.message}"
      return nil
    end

    parsed = [parsed] unless parsed.is_a?(Array)

    included = []
    excluded = []
    distance = []
    
    parsed.each do |piece|
      if phrase = (piece[:term] or piece[:word] or piece[:phrase])
        phrase = phrase.to_s
        
        if piece[:prohibited] or (piece[:op] == "NOT")
          excluded << {'phrase' => phrase}

        elsif piece[:distance] and piece[:distance].to_s.to_i > 0
          # split phrase into words
          # (doesn't support distance between multi-word phrases)
          # (doesn't support citations)
          distance << {
            'terms' => phrase.split(" "),
            'distance' => piece[:distance]
          }

        else
          included << {'phrase' => phrase}
        end

      end
    end

    {'included' => included, 'excluded' => excluded, 'distance' => distance}
  end

end
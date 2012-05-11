# Used to manage admin emails (reports, warnings, etc.)

module Admin

  def self.new_feed(subscription)
    title = subscription.data['title']
    url = subscription.data['url']

    original_title = subscription.data['original_title']
    original_description = subscription.data['original_description']

    subject = "[Review] New feed: #{title}"
    
    body = "Title: #{title}\nURL: #{url}\n\n"
    body += "Original Title: #{original_title}\n\nOriginal Description: #{original_description}"

    body += "\n\n#{JSON.pretty_generate subscription.attributes}"

    body += "\n\n#{subscription.id}"

    deliver! "Feed", subject, body.strip
  end

  def self.report(report)
    subject = "[#{report.status}] #{report.source} | #{report.message}"
      
    body = "#{report.id}"

    body += "\n\n#{report['message']}" if report['message'].present?

    if report[:attached]['exception']
      body += "\n\n#{exception_message(report)}"
    end
    
    attrs = report.attributes.dup
    
    [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}

    attrs['attached'].delete 'exception'
    attrs.delete('attached') if attrs['attached'].empty?
    body += "\n\n#{JSON.pretty_generate attrs}" if attrs.any?
      
    deliver! "Report", subject, body.strip
  end

  def self.message(subject, body = nil)
    deliver! "Admin", "[ADMIN] #{subject}", (body || subject)
  end

  def self.deliver!(tag, subject, body)
    if admin?
      Email.deliver!(tag, config[:admin], subject, body)
    else
      puts "\n[#{tag}] #{subject}\n\n#{body}"
    end
  end

  def self.admin?
    config[:admin].present? and config[:admin].any?
  end

  def self.exception_message(report)
    
    msg = ""
    msg += "#{report[:attached]['exception']['type']}: #{report[:attached]['exception']['message']}" 
    msg += "\n\n"
    
    if report[:attached]['exception']['backtrace'].respond_to?(:each)
      report[:attached]['exception']['backtrace'].each {|line| msg += "#{line}\n"}
    end
    
    msg
  end
  
end
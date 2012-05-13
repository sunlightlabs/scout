# Used to manage admin emails (reports, warnings, etc.)

module Admin

  def self.new_user(user)
    user_attributes = user.attributes.dup
    
    # it's just a salted hash, but still
    user_attributes.delete "password_hash"

    deliver! "User", "New user: #{user.email}", JSON.pretty_generate(user_attributes)
  end

  def self.new_feed(interest)
    title = interest.data['title']
    url = interest.data['url']

    original_title = interest.data['original_title']
    original_description = interest.data['original_description']

    subject = "New feed: #{title}"
    
    body = "Title: #{title}\nURL: #{url}\n\n"
    body += "Original Title: #{original_title}\n\nOriginal Description: #{original_description}"

    body += "\n\n#{JSON.pretty_generate interest.attributes}"

    if interest.seen_items.any?
      example = interest.seen_items.first
      body += "\n\nExample item:"
      body += "\n\n#{JSON.pretty_generate example.attributes}"
    end

    body += "\n\n#{interest.id}"

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
    deliver! "Admin", subject, (body || subject)
  end

  def self.deliver!(tag, subject, body)
    if admin?
      Email.deliver!(tag, config[:admin], "[ADMIN] #{subject}", body)
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
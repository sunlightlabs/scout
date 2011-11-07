require 'pony'

module Email

  def self.report(report)
    subject = "[#{report.status}] #{report.source} | #{report.message}"
      
    body = ""
    if report[:attached]['exception']
      body += exception_message(report)
    end
    
    attrs = report.attributes.dup
    [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}
    attrs['attached'].delete 'exception'
    attrs.delete('attached') if attrs['attached'].empty?
    body += attrs.inspect if attrs.any?
      
    if config[:email][:from].present? and config[:admin][:email].present?
      begin
        Pony.mail config[:email].merge(
          :subject => subject, 
          :body => body,
          :to => config[:admin][:email]
        )
      rescue Errno::ECONNREFUSED
        puts "Couldn't email report, connection refused! Check system settings."
      end
    else
      puts "\n[ADMIN EMAIL] #{body}"  
    end
  end

  def self.admin(subject, body = nil)
    if config[:email][:from].present? and config[:admin][:email].present?
      begin
        Pony.mail config[:email].merge(
          :subject => "[ADMIN] #{subject}",
          :body => body || subject,
          :to => config[:admin][:email]
        )
      rescue Errno::ECONNREFUSED
        puts "Couldn't email message, connection refused! Check system settings."
      end
    else
      puts "(No admin email, not sending real email)"
      puts "\n[ADMIN EMAIL] #{subject}\n\n#{body}"
    end
  end

  def self.exception_message(report)
    
    msg = ""
    msg += "#{report[:attached]['exception']['type']}: #{report[:attached]['exception']['message']}" 
    msg += "\n\n"
    
    if report[:attached]['exception']['backtrace'].respond_to?(:each)
      report[:attached]['exception']['backtrace'].each {|line| msg += "#{line}\n"}
      msg += "\n\n"
    end
    
    msg
  end

  def self.user(email, subject, content)
    if config[:email][:from].present?
      begin
        
        Pony.mail config[:email].merge(
          :to => email, 
          :subject => subject, 
          :body => content
        )
        
        true
      rescue Errno::ECONNREFUSED
        false
      end
    else
      puts "\n[USER] Would have delivered this to #{email}:"
      puts "\nSubject: #{subject}"
      puts "\n#{content}"
      true # if no 'from' email is specified, we'll assume it's a dev environment or something
    end
  end

end
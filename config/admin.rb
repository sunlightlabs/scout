# Used to manage admin emails (reports, warnings, etc.)

module Admin

  def self.new_user(user)
    user_attributes = user.attributes.dup
    
    # it's just a salted hash, but still
    user_attributes.delete "password_hash"

    message = "New user: #{user.email || user.phone}"

    if user.service
      message = "[#{user.service}] #{message}"
    end

    deliver! "New User", message, JSON.pretty_generate(user_attributes)
  end

  def self.bounce_report(description, data)
    deliver! "Email Bounce", "Bounce: #{description}", JSON.pretty_generate(data)
  end

  def self.user_unsubscribe(user, data)
    deliver! "Unsubscribe", "Unsubscribe: #{user.contact}", JSON.pretty_generate(data)
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

  # special case - a notice that Postmark itself is down, and email defaulted to Pony.
  # this email itself should be forced to be sent over Pony.
  # this isn't ideal, since it's bypassing some of the wrapper code around mail sending.
  # def self.postmark_down(original_tag, original_to, original_subject, original_body)
  #   subject = "[ADMIN] Postmark failed to send email, fell back to Pony"
  #   body = JSON.pretty_generate({
  #     :tag => original_tag, :to => original_to, :subject => original_subject, :body => original_body
  #   })

  #   unless Email.with_pony!("Postmark Down", admin_emails, subject, body)
  #     Event.email_failed! original_tag, original_to, original_subject, original_body
  #     puts "\n[ADMIN][#{Pony}] Failed to send email to admin that Postmark is down...oh well."
  #   end
  # end

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
      # admin emails always use pony, even if postmark is on for the app in general
      Email.with_pony!(tag, admin_emails, "[ADMIN] #{subject}", body)
    else
      puts "\n[#{tag}] #{subject}\n\n#{body}" unless Sinatra::Application.test?
    end
  end

  def self.admin?
    admin_emails.present? and admin_emails.any?
  end

  def self.admin_emails
    config[:admin]
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
# Used to manage admin emails (reports, warnings, etc.)

module Admin

  # if Sentry is configured, uses Sentry.
  # if not, uses normal admin email route (SMTP).
  def self.exception(source, exception, extra = {})

    if Environment.config['sentry'].present?
      Raven.capture_exception(
        exception,
        extra: extra.merge(
          source: source,
        )
      )

    else
      message = "#{exception.class.name}: #{exception.message}"
      report = Report.exception source, message, exception, extra
      Admin.report report
    end
  end

  def self.new_user(user)
    user_attributes = user.attributes.dup

    # it's just a salted hash, but still
    user_attributes.delete "password_hash"

    message = "New user: #{user.email || user.phone}"

    if user.service
      message = "[#{user.service}] #{message}"
    end

    if user.signup_process == "quick"
      subject = "New User [quick]"
    else
      subject = "New User"
    end

    deliver! subject, message, JSON.pretty_generate(user_attributes)
  end

  def self.confirmed_user(user)
    message = "User confirmed: #{user.email || user.phone}"
    deliver! "Confirmed User", message, ""
  end

  def self.bounce_report(description, data)
    deliver! "Email Bounce", "Bounce: #{description}", JSON.pretty_generate(data)
  end

  def self.user_unsubscribe(user, data)
    deliver! "Unsubscribe", "Unsubscribe: #{user.contact}", JSON.pretty_generate(data)
  end

  def self.analytics(type, subject, body)
    deliver! "Analytics", subject, body, analytics_emails[type], "Analytics"
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
      body += "\n\n#{exception_message report}"
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

  def self.deliver!(tag, subject, body, recipients = nil, email_tag = nil)
    recipients ||= admin_emails
    email_tag ||= "ADMIN"

    if admin?
      # admin emails always use pony, even if postmark is on for the app in general
      Email.with_pony!(tag, recipients, "[#{email_tag}] #{subject}", body)
    else
      puts "\n[#{tag}] #{subject}\n\n#{body}" unless Sinatra::Application.test?
    end
  end

  def self.admin?
    admin_emails.present? and admin_emails.any?
  end

  def self.admin_emails
    Environment.config['admin']
  end

  def self.analytics_emails
    Environment.config['analytics']
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
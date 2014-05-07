# Used to manage admin emails (reports, warnings, etc.)

module Admin

  # SCHEDULE: Unpredictable. Whenever an uncaught exception occurs.
  #
  # if Sentry is configured, uses Sentry.
  # if not, uses normal admin email route (SMTP).
  def self.exception(source, exception, extra = {})
    message = "#{exception.class.name}: #{exception.message}"

    if Environment.config['sentry'].present?
      puts "Sending to Raven: [#{source}] #{message}"
      Raven.capture_exception(
        exception,
        extra: extra.merge(
          source: source,
        )
      )
      # Sentry will email admin and post to Slack on its own
    else
      Admin.report report
      report = Report.exception source, message, exception, extra
    end
  end

  # SCHEDULE: Whenever a user uses the one-click unsubscribe button.
  def self.user_unsubscribe(user, data)
    deliver! "Unsubscribe", "Unsubscribe: #{user.contact}", JSON.pretty_generate(data)
  end

  # SCHEDULE: A weekly email is sent with user activity stats.
  def self.analytics(type, subject, body)
    Slack.message! subject, body
    deliver! "Analytics", subject, body, analytics_emails[type], "Analytics"
  end

  # General purpose: used to send various exception/warning reports to the admin.
  def self.report(report, email: true, slack: true)
    subject = "[#{report.status}] #{report.source} | #{report.message}"

    body = "#{report.id}"

    body += "\n\n#{report['message']}" if report['message'].present?

    if report[:attached][:header]
      body += "\n\n"
      body += report[:attached].delete :header
    end

    if report[:attached]['exception']
      body += "\n\n#{exception_message report}"
    end

    attrs = report.attributes.dup

    [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}

    attrs['attached'].delete 'exception'
    attrs.delete('attached') if attrs['attached'].empty?
    body += "\n\n#{JSON.pretty_generate attrs}" if attrs.any?
    body.strip!

    # slack is disabled when the report may have sensitive data,
    # or when Slack integration itself has a problem.
    if slack
      Slack.message! subject, body
    end

    # email is only disabled when we already posted to Sentry.
    if email
      deliver! "Report", subject, body
    end
  end

  # General purpose.
  def self.message(subject, body = nil)
    Slack.message! subject, body
    deliver! "Admin", subject, (body || subject)
  end

  # General purpose, but don't post to Slack.
  def self.sensitive(subject, body = nil)
    deliver! "Admin", subject, (body || subject)
  end

  # Workhorse: actually sends the admin emails. Does not use Postmark.
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
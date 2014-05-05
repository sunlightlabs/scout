# wraps the choice of email mechanism - can either be pony or postmark, depending on the config settings

require 'pony'
require 'postmark'

module Email

  # used when you want the email to use whatever's in the settings
  def self.deliver!(tag, to, subject, body, from = nil, reply_to = nil)
    unless email?
      sent_message "FAKE", tag, to, subject, body, from, reply_to
      return true
    end

    if Environment.config['email']['via'] == 'pony'
      with_pony! tag, to, subject, body, from, reply_to
    elsif Environment.config['email']['via'] == 'postmark'
      with_postmark! tag, to, subject, body, from, reply_to
    else
      puts "[#{tag}][ERROR] No delivery method specified."
      false
    end

  # Important that this method *not* raise any Exceptions,
  # because our top-level generic exception handlers will
  # cause an error report to get sent, leading to an infinite loop.

  rescue Exception => exc
    puts "EXCEPTION SENDING EMAIL:"
    puts "\n#{exc.class}"
    puts "\n#{exc.message}"
    if exc.backtrace and exc.backtrace.respond_to?(:each)
      exc.backtrace.each do |line|
        puts line
      end
    end
  end

  # send using a plain SMTP client
  def self.with_pony!(tag, to, subject, body, from = nil, reply_to = nil)
    unless email?
      sent_message "FAKE", tag, to, subject, body, from, reply_to
      return true
    end

    # Pony demands symbol keys for everything, but using safe_yaml
    # commits us to string keys.
    options = {
      via: Environment.config['email']['pony']['via'].to_sym,
      via_options: {
        address: Environment.config['email']['pony']['via_options']['address'],
        port: Environment.config['email']['pony']['via_options']['port'],
        user_name: Environment.config['email']['pony']['via_options']['user_name'],
        password: Environment.config['email']['pony']['via_options']['password'],
        authentication: Environment.config['email']['pony']['via_options']['authentication'],
        domain: Environment.config['email']['pony']['via_options']['domain'],
        enable_starttls_auto: Environment.config['email']['pony']['via_options']['enable_starttls_auto']
      }
    }
    options[:from] = from || Environment.config['email']['from']
    options[:reply_to] = reply_to || Environment.config['email']['reply_to']

    begin
      if html_tags.include?(tag) # html emails
        Pony.mail options.merge(subject: subject, html_body: body, to: to)
      else
        Pony.mail options.merge(subject: subject, body: body, to: to)
      end

      sent_message "Pony", tag, to, subject, body, from, reply_to
      true
    rescue Errno::ECONNREFUSED
      puts "\n[#{tag}][Pony] Couldn't email message, connection refused! Check email settings."
      false
    end
  end

  # send using the Postmark service
  def self.with_postmark!(tag, to, subject, body, from = nil, reply_to = nil)
    unless email?
      sent_message "FAKE", tag, to, subject, body, from, reply_to
      return true
    end

    api_key = Environment.config['email']['postmark']['api_key']
    client = Postmark::ApiClient.new api_key, secure: true, http_open_timeout: 15

    options = {
      from: from || Environment.config['email']['from'],
      reply_to: reply_to || Environment.config['email']['reply_to'],
      to: to,
      subject: subject,
      tag: tag
    }

    if html_tags.include?(tag)
      options[:html_body] = body # content_type = "text/html"
    else
      options[:text_body] = body # content_type = "text/plain"
    end

    begin
      client.deliver options

      sent_message "Postmark", tag, to, subject, body, from, reply_to
      true
    rescue Exception => e
      # if it's a hard bounce to a valid user, unsubscribe that user from future emails
      if e.is_a?(Postmark::InvalidMessageError) and e.message["hard bounce or a spam complaint"]
        if user = User.where(email: to).first

          # true = bounce report
          user.unsubscribe! true

          Admin.report(
            Report.exception "Postmark Exception", "Bad email: #{to}, user unsubscribed", e,
              tag: tag, to: to, subject: subject, body: body, from: from, reply_to: reply_to
          )
        else
          Admin.report(
            Report.exception "Postmark Exception", "Weird: Bad email: #{to}, but no user found by that email!", e,
              tag: tag, to: to, subject: subject, body: body, from: from, reply_to: reply_to
          )
        end

      else
        # email admin with details of Postmark exception, but try to deliver with Pony
        Admin.report(
          Report.exception "Postmark Exception", "Failed to email #{to}, trying to deliver via SMTP", e,
            tag: tag, to: to, subject: subject, body: body, from: from, reply_to: reply_to
        )

        puts "\n[#{tag}][Postmark] Couldn't send message to Postmark. Trying Pony as a backup."

        # backup, try to use Pony to send the message
        if with_pony!(tag, to, subject, body)
          Event.postmark_failed! tag, to, subject, body
          true
        else
          puts "\n[#{tag}][Pony] Nope, failed to send via Pony too. Oh well!"
          Event.email_failed! tag, to, subject, body
          false
        end
      end
    end
  end

  def self.html_tags
    ["User Alert", "User Confirm Email", "Password Reset Request", "Password Reset"] #, "Analytics"]
  end

  # always disable email in test mode
  # allow development mode to disable email by withholding the from email
  def self.email?
    !Sinatra::Application.test? and Environment.config['email']['from'].present?
  end

  def self.sent_message(method, tag, to, subject, body, from = nil, reply_to = nil)
    return if Sinatra::Application.test?

    puts
    puts "--------------------------------"
    puts "[#{tag}][#{method}] Delivered to #{to}: #{from ? "(from: #{from})" : nil}"
    puts "\n= Subject: #{subject}"
    puts "\n#{body}"
    puts "--------------------------------"
    puts
  end

end
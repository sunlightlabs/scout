
require 'twilio-rb'

module SMS

  def self.deliver!(tag, phone, body)
    if sms?
      Twilio::SMS.create :to => phone, :from => config[:twilio][:from], :body => body
      sent_message "Twilio", tag, phone, body
    else
      sent_message "FAKE", tag, phone, body
    end

    true
  rescue Exception => ex
    Admin.report Report.exception("SMS Delivery", "Error delivering SMS through Twilio", ex, :tag => tag, :phone => phone, :content => content)
    false
  end

  # always disable email in test mode
  # allow development mode to disable email by withholding the from email
  def self.sms?
    !Sinatra::Application.test? and config[:twilio][:from].present?
  end

  def self.sent_message(method, tag, phone, body)
    return if Sinatra::Application.test?
    
    puts
    puts "--------------------------------"
    puts "[#{tag}][#{method}] SMS to #{phone}:"
    puts "\n#{body}"
    puts "--------------------------------"
    puts
  end

end
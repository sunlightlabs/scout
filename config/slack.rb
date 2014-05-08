require 'slack-notifier'

module Slack

  def self.message!(subject, body = nil)
    config = Environment.config
    return unless slack?

    notifier = Slack::Notifier.new config['slack']['team'], config['slack']['token']
    notifier.channel = config['slack']['channel']
    notifier.username = config['slack']['username']

    # just to be nice, add the colons if not configured correctly
    emoji = config['slack']['icon_emoji']
    emoji = ":#{emoji}:" if emoji[":"].nil?

    if body
      message = [subject, "```\n#{body}\n```"].join("\n\n")
    else
      message = subject
    end

    notifier.ping message, icon_emoji: emoji
  rescue Exception => exc
    report = Report.exception 'Slack notifications', "Exception notifying slack", ex
    Admin.report report, slack: false # don't try to slack a slack error
    puts "Error notifying slack, emailed report."
  end

  # always disable slack in test mode
  # allow development mode to disable slack by withholding the slack section/team
  def self.slack?
    !Sinatra::Application.test? and config['slack'] and config['slack']['team'].present?
  end

end
class Event
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type
  field :description
  field :data, type: Hash

  index :type

  scope :for_time, ->(start, ending) {where(created_at: {"$gt" => Time.zone.parse(start).midnight, "$lt" => Time.zone.parse(ending).midnight})}

  def self.unsubscribe!(interest)
    create!(
      type: "unsubscribe-alert", 
      description: "#{interest.user.contact} from #{interest.in}", 
      data: interest.attributes.dup
    )
  end

  def self.email_failed!(tag, to, subject, body)
    create!(
      type: "email-failed",
      description: "Postmark down, SMTP failed also",
      data: {
        tag: tag, to: to, subject: subject, body: body
      }
    )
  end

  def self.postmark_bounce!(email, bounce_type, details)
    create!(
      type: "postmark-bounce",
      description: "#{bounce_type} for #{email}",
      data: details
    )
  end
end
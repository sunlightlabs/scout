require 'bcrypt'

require 'gman'
require 'swot'

# A subscriber.
#
# Scout can act as a white-label service for other services. For example,
# Sunlight's OpenStates uses Scout. Third-party services are configured in
# `config/services.yml`.
class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  # @return [String] the subscriber's email address
  field :email
  # @return [String] the subscriber's phone number
  field :phone

  # @return [String] one of "web", "remote" or a third-party service's ID
  field :source, default: "web"

  # @return [String] the service that generated the user, if not Scout itself,
  #   e.g. "open_states"
  field :service, default: nil
  # @return [Time] the time at which the user was last synced with the remote
  #   service that generated the user
  field :synced_at, type: Time

  # @return [String] one of:
  #   * "email_immediate": the user will receive notifications immediately
  #   * "email_daily" the user will receive notifications daily
  #   * "none": the user will not receive notifications
  field :notifications, default: "email_immediate"
  validates_inclusion_of :notifications, in: ["none", "email_daily", "email_immediate"] # sms not valid at the user level
  validates_presence_of :notifications

  # @return [Boolean] whether the user receives announcements about Scout
  field :announcements, type: Boolean, default: false
  # @return [Boolean] whether the user receives announcements about the
  #   organization that has deployed Scout
  field :sunlight_announcements, as: :organization_announcements, type: Boolean, default: false

  # @return [String] the user's username, used in public URLs
  field :username
  # @return [String] the user's public name
  field :display_name
  # @return [String] a URL the user chooses to display with their account
  field :url
  # @return [String] the user's biography
  field :bio
  # @return [String] the user's public email address
  field :contact_email

  # @return [Boolean] whether the email comes from government
  field :government, type: Boolean, default: false
  # @return [Boolean] whether the email comes from education
  field :education, type: Boolean, default: false


  # validates_format_of :url, with: URI::regexp(%w(http https)), message: "Not a valid URL.", allow_blank: true

  has_mongoid_attached_file :image,
    path: 'public/system/:attachment/:id/:style.:extension',
    url: '/system/:attachment/:id/:style.:extension',
    # storage: :s3,
    # url: ':s3_alias_url',
    # s3_host_alias: 'something.cloudfront.net',
    # s3_credentials: File.join('config', 's3.yml'),
    styles: {
      # original: ['1000x1000>', :png],
      small: ['217x217>', :png]
    }

  validates_attachment_size :image, in: 0..1.megabytes, message: "Image must be less than 1MB."

  index username: 1
  index user_id: 1
  index government: 1
  index edcuation: 1

  validates_uniqueness_of :username, allow_blank: true, message: "has already been taken."
  validates_exclusion_of :username, in: reserved_names, message: "cannot be used."

  has_many :interests, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :subscriptions # interests will destroy their own subscriptions
  has_many :seen_items # interests will destroy their own seen_items
  has_many :deliveries # interests will destroy their own deliveries
  has_many :receipts # never destroy receipts

  scope :for_time, ->(start, ending) {where(created_at: {"$gt" => Time.zone.parse(start).midnight, "$lt" => Time.zone.parse(ending).midnight})}
  scope :open_states, where(service: "open_states")
  scope :scout, where(service: nil)

  before_validation :slugify_username
  # @private
  def slugify_username
    if self.username.present?
      self.username = self.username.gsub(/[^\w\d\s]/, '')
      self.username = self.username.strip.downcase
      self.username = self.username.gsub(/\s+/, '_')
    end
  end

  before_save :check_email_type
  def check_email_type
    return unless email.present?

    self.government = Gman.valid? email
    self.education = Swot::is_academic? email

    true
  end

  def contact
    if email.present?
      email
    else
      phone
    end
  end

  # delivery notification stuff
  def allowable_notifications
    types = []
    types << "email_daily" if email.present?
    types << "email_immediate" if email.present?
    types << "sms" if phone.present? and phone_confirmed
    types << "none"
    types
  end

  # user authentication stuff

  field :signup_process, default: nil # can be "quick"

  attr_accessible :email, :username, :display_name, :phone,
    :notifications, :announcements, :organization_announcements,
    :bio, :image, :url, :contact_email

  attr_accessor :password, :password_confirmation

  field :password_hash, type: String # type needs to be specified, otherwise it'd be a BCrypt::Password
  validates_confirmation_of :password, :message => "Your passwords did not match."

  before_save :encrypt_password

  def self.email_format
    /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i
  end

  validates_presence_of :email, message: "We need an email address.", :unless => :has_phone?
  validates_uniqueness_of :email, message: "That email address is already signed up.", :allow_blank => true
  validates_format_of :email, with: email_format, message: "Not a valid email address.", allow_blank: true


  # used to allow email-less user accounts
  # @private
  def has_phone?
    self.phone.present?
  end

  def self.authenticate(user, password)
    BCrypt::Password.new(user.password_hash) == password
  end

  # @private
  def encrypt_password
    if password # should only occur if a new password has been set on this user
      self.password_hash = BCrypt::Password.create password
    end
  end


  # account confirmation

  # accounts that sign up through the regular login process are auto-confirmed
  # accounts that sign up through the one-click alert button are *not* confirmed
  # accounts signed up through the remote API have a confirmation step
  field :confirmed, type: Boolean

  # it's okay if they always have a confirm token even when confirmed
  field :confirm_token
  validates_uniqueness_of :confirm_token, allow_nil: true
  before_validation :new_confirm_token, on: :create

  def new_confirm_token
    self.confirm_token = User.friendly_token
  end


  # password resetting fields and logic

  field :reset_token
  validates_uniqueness_of :reset_token
  before_validation :new_reset_token, on: :create

  # set after a password is reset
  field :should_change_password, type: Boolean, default: false

  # taken from authlogic
  # https://github.com/binarylogic/authlogic/blob/master/lib/authlogic/random.rb
  # @private
  def self.friendly_token
    # use base64url as defined by RFC4648
    SecureRandom.base64(15).tr('+/=', '').strip.delete("\n")
  end

  # @private
  def self.short_token
    "%04d" % rand(10000)
  end

  def new_reset_token
    self.reset_token = User.friendly_token
  end

  def reset_password(short = false)
    new_password = short ? User.short_token : User.friendly_token
    self.password = new_password
    self.password_confirmation = new_password
    self.should_change_password = true

    # need to return the actual password, so it can be emailed
    new_password
  end


  # phone number confirming and verification logic

  field :phone_verify_code
  field :phone_confirmed, type: Boolean, default: false

  # only +, -, ., and digits allowed
  validates_uniqueness_of :phone, :allow_blank => true, message: "has been taken"

  before_validation :standardize_phone, :if => :has_phone?

  # @private
  def standardize_phone
    if Phoner::Phone.valid?(self.phone)
      self.phone = Phoner::Phone.parse(self.phone).to_s
    else
      errors.add(:base, "Not a valid phone number.")
    end
  end

  # runs the phone standardizer on lookup
  def self.by_phone(phone)
    phone = phone.dup # apparently Phoner can't handle frozen strings??
    if Phoner::Phone.valid?(phone)
      standard = Phoner::Phone.parse(phone).to_s
      where(phone: standard).first
    else
      nil
    end
  end

  def new_phone_verify_code
    self.phone_verify_code = User.short_token
  end

  # turn off the user's email notifications, and any announcement subscriptions
  # log the user's unsubscription in the events table, and what the user's settings were
  def unsubscribe!(description = nil)
    old_info = {
      notifications: self.notifications,
      announcements: self.announcements,
      organization_announcements: self.organization_announcements,
      service: self.service # context
    }

    self.notifications = "none"
    self.announcements = false
    self.organization_announcements = false
    self.save!

    # unsubscribe individual interests
    self.interests.each do |interest|
      interest.notifications = nil
      interest.save!
    end

    Event.unsubscribe! self, old_info, description
  end
end

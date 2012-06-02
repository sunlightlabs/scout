require 'bcrypt'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :email
  field :phone

  # accounts that sign up through the regular login process are auto-confirmed
  # accounts signed up through the remote API have a confirmation step
  field :confirmed, :type => Boolean, :default => true

  # by default, accounts come from the web - we allow a remote API for limited use cases
  field :source, default: "web"

  # will get assigned automatically by the API key syncing service
  # if a user has one, we turn on various features in the site
  field :api_key

  # whether and how the user will receive notifications
  field :notifications, :default => "email_immediate"
  validates_inclusion_of :notifications, :in => ["none", "email_daily", "email_immediate"] # sms not valid at the user level
  validates_presence_of :notifications

  # boolean as to whether users wish to receive announcements about Scout features
  # defaults to true (opt-out)
  field :announcements, :type => Boolean, :default => true
  field :sunlight_announcements, :type => Boolean, :default => false

  # used for sharing things
  field :username
  field :display_name

  validates_uniqueness_of :username, :allow_blank => true, :message => "has already been taken."
  validates_exclusion_of :username, :in => reserved_names, :message => "cannot be used."

  has_many :interests, :dependent => :destroy
  has_many :subscriptions # interests will destroy their own subscriptions
  has_many :deliveries, :dependent => :destroy
  has_many :tags, :dependent => :destroy


  before_validation :slugify_username
  def slugify_username
    if self.username.present?
      self.username = self.username.gsub(/[^\w\d\s]/, '')
      self.username = self.username.strip.downcase
      self.username = self.username.gsub(/\s+/, '_')
    end
  end


  after_save :find_api_key

  def developer?
    api_key.present?
  end

  def find_api_key
    if key = ApiKey.where(:email => email).first
      ApiKey.sync_with_user! key, self
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

  attr_accessor         :password, :password_confirmation
  attr_protected        :password_hash
  
  field :password_hash, :type => String # type needs to be specified, otherwise it'd be a BCrypt::Password
  
  validates_presence_of :email, :message => "We need an email address.", :unless => :has_phone?
  validates_uniqueness_of :email, :message => "That email address is already signed up.", :allow_blank => true
  validates_format_of :email, :with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, :message => "Not a valid email address.", :allow_blank => true

  validates_confirmation_of :password, :message => "Your passwords did not match."
  
  before_save :encrypt_password
  
  # used to allow email-less user accounts
  def has_phone?
    self.phone.present?
  end

  def self.authenticate(user, password)
    BCrypt::Password.new(user.password_hash) == password
  end
  
  def encrypt_password
    if password # should only occur if a new password has been set on this user
      self.password_hash = BCrypt::Password.create password
    end
  end

  # password resetting fields and logic

  field :reset_token
  validates_uniqueness_of :reset_token
  before_validation :new_reset_token, :on => :create

  # set after a password is reset
  field :should_change_password, :type => Boolean, :default => false

  # taken from authlogic
  # https://github.com/binarylogic/authlogic/blob/master/lib/authlogic/random.rb
  def self.friendly_token
    # use base64url as defined by RFC4648
    SecureRandom.base64(15).tr('+/=', '').strip.delete("\n")
  end

  def self.short_token
    zero_prefix rand(10000)
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
  field :phone_confirmed, :type => Boolean, :default => false

  # only +, -, ., and digits allowed
  validates_uniqueness_of :phone, :allow_blank => true
  # validates_format_of :phone, :with => /^[\+\.\d\-]+$/, :allow_blank => true, :message => "Not a valid phone number."

  validate :standardize_phone, :if => :has_phone?

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

  # zero prefixes a number below 10,000 out to 4 digits
  def self.zero_prefix(number)
    if number < 10
      "000#{number}"
    elsif number < 100
      "00#{number}"
    elsif number < 1000
      "0#{number}"
    else
      number.to_s
    end
  end

  def self.phone_verify_message(code)
    "[Scout] Your verification code is #{code}."
  end

  def self.phone_remote_subscribe_message
    "You've been signed up for SMS alerts. Confirm your phone number by replying to this text with 'C'."
  end

  def self.phone_remote_confirm_message(password)
    "Your number has been confirmed. Log in to scout.sunlightfoundation.com with the password \"#{password}\" to manage your alerts." # Text \"HELP\" for a list of commands."
  end
end
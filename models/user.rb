require 'bcrypt'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :admin, :type => Boolean, :default => false

  field :email
  field :phone

  # metadata on user delivery preferences
  field :delivery, :type => Hash, :default => {}
  #   mechanism: ['email', 'sms']
  #   email_frequency: ['daily', 'immediate']

  has_many :subscriptions, :dependent => :destroy
  has_many :interests, :dependent => :destroy
  has_many :deliveries, :dependent => :destroy
  
  validate :phone_for_sms

  # shorthand for delivery information
  def mechanism
    delivery['mechanism']
  end

  def frequency
    if mechanism == 'email'
      delivery['email_frequency']
    elsif mechanism == 'sms'
      'immediate'
    else
      ""
    end
  end

  def phone_for_sms
    if mechanism == 'sms' and phone.blank?
      errors.add(:phone, "A phone number is required for SMS.") and return false
    end
  end

  # user authentication stuff

  attr_accessor         :password, :password_confirmation
  attr_protected        :password_hash
  
  field :password_hash, :type => String # type needs to be specified, otherwise it'd be a BCrypt::Password
  
  validates_presence_of :email, :message => "We need an email address."
  validates_uniqueness_of :email, :message => "That email address is already signed up."
  validates_format_of :email, :with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, :message => "Not a valid email address."
  validates_confirmation_of :password, :message => "Your passwords did not match."
  
  before_save :encrypt_password
  
  def self.authenticate(user, password)
    BCrypt::Password.new(user.password_hash) == password
  end
  
  def encrypt_password
    self.password_hash = BCrypt::Password.create password
  end

end
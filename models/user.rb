class User
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :email
  field :phone

  # metadata on user delivery preferences
  field :delivery, :type => Hash
  #   mechanism: ['email', 'sms']
  #   email_frequency: ['daily', 'immediate']

  has_many :subscriptions
  has_many :interests
  has_many :deliveries
  
  validates_presence_of :email
  validates_uniqueness_of :email

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
      errors.add(:phone, "is required for SMS.") and return false
    end
  end
end
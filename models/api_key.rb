class ApiKey
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :key
  field :email
  field :status
  
  validates_presence_of :key
  validates_presence_of :email
  validates_presence_of :status
  validates_uniqueness_of :key
  validates_uniqueness_of :email
  
  index :key
  index :email
  index :status

  after_save :mark_user

  # update any user account with the same email
  def mark_user
    new_user = User.where(:email => email).first
    old_user = User.where(:api_key => key).first

    # if the key changed hands for some reason, strip the old user of their key
    if old_user and (new_user != old_user)
      old_user.api_key = nil
      old_user.save!
    end

    # only set active keys
    if new_user
      if status == "A"
        new_user.api_key = key
      else
        new_user.api_key = nil
      end
      new_user.save!
    end
  end
end
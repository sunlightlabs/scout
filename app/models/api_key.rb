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
  
  index key: 1
  index email: 1
  index status: 1

  after_save :mark_user

  def self.sync_with_user!(key, user)
    old_user = User.where(:api_key => key.key).first

    # if the key changed hands for some reason, strip the old user of their key
    if old_user and (user != old_user)
      old_user.set :api_key, nil
    end

    # only set active keys
    if user
      # using #set because it does not trigger callbacks, which could send this into an infinite loop
      if key.status == "A"
        user.set :api_key, key.key 
      else
        user.set :api_key, nil
      end
    end
  end

  # update any user account with the same email
  def mark_user
    if user = User.where(:email => email).first
      ApiKey.sync_with_user! self, user
    end
  end

  def self.allowed?(key)
    !ApiKey.where(:key => key, :status => 'A').first.nil?
  end

end
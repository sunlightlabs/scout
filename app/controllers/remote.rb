# endpoint for accepting subscriptions from Twilio for SMS subscribers
# auto-signs up a user by phone number alone, adds subscription for a given bill
# 
# requirements: 
#   phone: a phone number (should not have an account tied to it already)
#   interest_type: "item"
#   item_type: "bill"
#   item_id: bill ID (e.g. "hr1234-112")
#
# optional:
#   source: string describing source (defaults to "remote")
#
# will return 500 if phone is blank, or taken
# will return 500 if interest_type is not "item"
# will return 500 if item_type is not "bill"
# will return 500 if item_id is blank
# will return 500 if remote item is not actually found
# will return 500 if credentials fail (todo)
#
# user requirements must be relaxed to allow no email address
# user will be texted a random password to log in with
# 
# user will be produced with:
#   source: "remote"
#   confirmed: false
#   announcements: false
#   sunlight_announcements: false
#   notifications: none
#   phone: [phone number]
#   phone_confirmed: false
#   password_hash: [generated random pass]
#   should_change_password: true
#
# item interest for this user will be generated as normal
# subscriptions will be initialized
#
# no notifications will be delivered, or deliveries scheduled, until user account is confirmed
post "/remote/subscribe/sms" do
  [:phone, :item_id, :interest_type, :item_type].each do |key|
    halt 500, "Include an '#{key}' parameter." unless params[key].present?
  end

  source = params[:source].present? ? params[:source] : "remote"

  item_type = params[:item_type]
  item_id = params[:item_id]

  new_record = true
  if user = User.where(:phone => params[:phone]).first
    new_record = false
  else
    user = User.new(
      confirmed: false,
      phone: params[:phone],
      phone_confirmed: false,
      source: source,
      announcements: false,
      sunlight_announcements: false,
      notifications: "none"
    )
    
    # this password is made but never seen by the user, it will be re-reset on confirmation
    user.reset_password

    halt 500, "Invalid user: #{user.errors.full_messages.join ", "}" unless user.valid?
  end

  # now check that the remote item is for real
  halt 500, "Couldn't find remote #{item_type}." unless item = Subscriptions::Manager.find(item_types[item_type]['adapter'], item_id)

  # from here on, we assume all code runs safely and there's no need to do a transaction
  if new_record
    user.save!
  end
  
  interest = Interest.for_item user, item_id, item_type
  interest.data = item.data
  interest.save! # should be harmless whether or not item is created

  # ask user to confirm their new subscription
  if new_record
    SMS.deliver! "Remote Subscription", user.phone, User.phone_remote_subscribe_message
  end

  json 200, {
    :message => "Account and subscription created.",
    :phone => user.phone
  }
end


# confirm an account that subscribed via SMS
# confirmation is given by a Twilio-verified response via SMS 
# from the number in question (no confirmation code needed)

post "/remote/confirm/sms" do
  
end
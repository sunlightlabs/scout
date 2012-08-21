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

  item_type = params[:item_type] || "bill" # temporary
  item_id = params[:item_id]

  new_record = true
  if user = User.by_phone(params[:phone])
    new_record = false
  else
    user = User.new(
      phone: params[:phone],
      announcements: false,
      sunlight_announcements: false,
      notifications: "none"
    )

    # most fields are protected from mass assignment
    user.confirmed = false
    user.phone_confirmed = false
    user.source = source
    
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
  interest.notifications = "sms" # force interests subscribed to this way to be sms notifications
  interest.data = item.data
  interest.save! # should be harmless whether or not item is created

  # ask user to confirm their new subscription
  if new_record
    Admin.new_user user
    SMS.deliver! "Remote Subscription", user.phone, User.phone_remote_subscribe_message
  end

  json 200, {
    :message => (new_record ? "Account and subscription created." : "Subscription created for account."),
    :phone => user.phone,
    :user_id => user.id.to_s,
    :interest_id => interest.id.to_s,
    :interest_in => interest.in,
    :item_type => interest.item_type
  }
end


# Twilio SMS receiving endpoint, unfortunately needs to be one giant thing
post "/remote/twilio/receive" do
  
  body = params['Body'] ? params['Body'].strip.downcase : nil
  phone = params['From'] ? params['From'].strip : nil
  halt 500 unless body.present? and phone.present?
  halt 404 unless user = User.by_phone(phone)

  if body == "c"
    halt 200 if user.confirmed?
    user.confirmed = true
    user.phone_confirmed = true
    new_password = user.reset_password true # with short token
    SMS.deliver! "Remote SMS Confirmation", user.phone, User.phone_remote_confirm_message(new_password)
    user.save!
  else
    SMS.deliver! "Remote Unknown Command", user.phone, "Unrecognized command."
  end

  status 200
end
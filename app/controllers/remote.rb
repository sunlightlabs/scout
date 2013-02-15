# endpoint for syncing alerts with other services, 
# for which Scout will serve as a whitelabeled alert system.
# 
# Receive POSTs, with a secret key, with an array of active and inactive interests.
#
# If the service is invalid, 403.
# If the secret key is wrong for that service, 403.
#
# If the user account does exist, but has a different service, 500.
# 
# If the user account does not exist, create it:
#   with the provided 'service' field
#   with the provided 'notifications' field
#   with the provided email address
#   confirmed=true
#   announcements and sunlight_announcements as false
#   random password (unsynced with other service)
#
# If the user account is invalid somehow, 400.
#
# For active interests:
#   if it exists, do nothing
#   if it doesn't exist, create it and save it
#
# For inactive interests:
#   if it doesn't exist, do nothing
#   if it does exist, delete it *unless* it has an updated_at timestamp that is newer than the timestamp provided for that interest
#
# Check validity of each new interest, and only save/delete interests if
# all new item interests successfully 'found' their referenced item. 
# If they did not, 500 without any changes to the user's account or interests.

post "/remote/service/sync" do
  # post body is JSON 
  request.body.rewind # in case someone already read it
  body = request.body.read
  
  begin
    data = JSON.load body
  rescue JSON::ParserError => ex
    halt 500, "Error parsing JSON body."
  end

  unless service = Environment.services[data['service']]
    halt 403, "Not a supported service."
  end

  unless data['secret_key'] and (service['secret_key'] == data['secret_key'])
    halt 403, "Not a supported service."
  end

  if (user = User.where(email: data['email']).first)
    unless user.service == data['service']
      halt 403, "Wrong service for this user."
    end
  else
    user = User.new(
      email: data['email'],
      notifications: data['notifications'],
      
      announcements: false,
      sunlight_announcements: false
    )

    user.confirmed = true
    user.should_change_password = false
    user.service = data['service']
    user.source = data['service']
    
    unless user.valid?
      halt 403, "Invalid new user."
    end
  end

  unless data['interests'] and data['interests'].any?
    halt 403, "Nothing to sync."
  end

  # figure out which interests should be added and removed
  to_remove = []
  to_add = []

  data['interests'].each do |change|
    # whether it's add or remove, load any interest we may have already

    # item subscriptions need to fetch remote details
    if change['interest_type'] == 'item'
      interest = Interest.for_item user, change['item_id'], change['item_type']

      # yes, this should go in the model
      if interest.new_record?
        unless item = Subscriptions::Manager.find(item_types[change['item_type']]['adapter'], change['item_id'])
          halt 403, "Couldn't fetch item details; bad ID, or data source is down."
        end
        interest.data = item.data
      end

    # search subscriptions
    elsif change['interest_type'] == 'search'
      interest = Interest.for_search user, change['search_type'], change['in'], change['query_type'], change['filters']
    else
      halt 403, "Unrecognized interest type."
    end

    if [true, "true"].include?(change['active'])
      if interest.new_record?
        to_add << interest
      else
        # pass: we're done, it exists
      end

    # removed subscription
    elsif [false, "false"].include?(change['active'])
      if interest.new_record?
        # pass: we're done, it doesn't exist
      else
        if change['changed_at'].is_a?(Float) or change['changed_at'].is_a?(Fixnum)
          changed_at = Time.at change['changed_at']
        else
          changed_at = Time.zone.parse(change['changed_at'])
        end
        
        if changed_at > interest.updated_at
          to_remove << interest
        else
          # pass: the user has updated it here more recently, somehow
        end
      end
    end
  end

  # make sure the user, and any new interests, are all valid
  # then save and delete everything, trusting it will all work out okay in the end
  bad_interests = to_add.select {|i| !i.valid?}
  if bad_interests.empty?
    
    # commit everything
    if user.new_record?
      user.save!
      Admin.new_user user
    else
      user.save!
    end

    to_add.each {|interest| interest.save!}
    to_remove.each {|interest| interest.destroy}
    user.reload

    halt 201, {
      actions: {
        added: to_add.size, 
        removed: to_remove.size,
      },

      user: {
        email: user.email,
        _id: user.id.to_s,
        notifications: user.notifications,
        interests: user.interests.map(&:to_remote)
      }
    }.to_json

  else
    message = "Some interests were invalid: #{bad_interests.inspect}"
    Admin.message message
    halt 403, message
  end

end


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


# Postmark bounce report receiving endpoint
post "/remote/postmark/bounce" do
  body = request.body.read.to_s
  doc = MultiJson.load body
  Event.postmark_bounce! doc['Email'], doc['Type'], doc
end
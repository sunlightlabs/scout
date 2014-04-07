# endpoint for syncing alerts with other services,
# for which Scout will serve as a whitelabeled alert system.
#
# Receive POSTs, with a secret key, with an array of active and inactive interests.
#
# If the service is invalid, 403.
# If the secret key is wrong for that service, 403.
#
# If the user account does exist, but has a different service,
# add it to their account like anything else. The service syncing this to us
# should understand that these new interests won't be whitelabeled. We whitelabel per-user,
# not per-interest, at this time.
#
# But note: this means that users who unsubscribed with Scout can get their settings
# reset, unless they or we communicate that back upstream to the provider we're whitelabeling for.
# So, for users who we auto-unsubscribe because Postmark returns an error, we also set
# their "confirmed" flag to false. This prevents users from being re-subscribed on sync.
#
# If the user account does not exist, create it:
#   with the provided 'service' field
#   with the provided 'notifications' field
#   with the provided email address
#   confirmed=true
#   announcements and organization_announcements as false
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
#   if it does exist, delete it
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
    # unless user.service == data['service']
    #   halt 403, "Wrong service for this user."
    # end

    # the remote service can take this opportunity to turn notifications on/off
    user.notifications = data['notifications']

  else
    user = User.new(
      email: data['email'],
      notifications: data['notifications'],

      announcements: false,
      organization_announcements: false
    )

    user.confirmed = true
    user.service = data['service']
    user.source = data['service']

    # set to a random password; for now we are not syncing passwords across services
    user.reset_password
    user.should_change_password = false # must come after the reset

    unless user.valid?
      halt 403, "Invalid new user."
    end
  end

  unless data['interests']
    halt 403, "Need a valid interests field."
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
        # if change['changed_at'].is_a?(Float) or change['changed_at'].is_a?(Fixnum)
        #   changed_at = Time.at change['changed_at']
        # else
        #   changed_at = Time.zone.parse(change['changed_at'])
        # end

        # if changed_at > interest.updated_at
          to_remove << interest
        # else
          # pass: the user has updated it here more recently, somehow
        # end
      end
    end
  end

  # make sure the user, and any new interests, are all valid
  # then save and delete everything, trusting it will all work out okay in the end
  bad_interests = to_add.select {|i| !i.valid?}
  if bad_interests.empty?

    # always update the last time a user was synced
    user.synced_at = Time.now

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


# Postmark bounce report receiving endpoint
post "/remote/postmark/bounce" do
  body = request.body.read.to_s
  doc = MultiJson.load body
  Event.postmark_bounce! doc['Email'], doc['Type'], doc
end
get '/account/subscriptions' do
  requires_login

  erb :"account/subscriptions", :locals => {
    :interests => current_user.interests.desc(:created_at),
    :tags => current_user.tags
  }
end

get '/account/unsubscribe' do
  requires_login "/login?redirect=/account/unsubscribe"

  erb :"account/unsubscribe"
end

post '/account/unsubscribe/actually' do
  requires_login

  event = current_user.unsubscribe!
  Admin.user_unsubscribe current_user, event['data']

  redirect "/account/unsubscribe"
end

get '/account/settings' do
  requires_login

  erb :"account/settings", :locals => {:user => current_user}
end

put '/account/settings' do
  requires_login
  
  # first, any attributes given under the user hash
  current_user.attributes = params[:user]

  # second, if there is a 'password' param then we need to verify the old password and pass in the confirmation
  if params[:password].present?
    unless User.authenticate(current_user, params[:old_password])
      flash.now[:password] = "Incorrect current password."
      return erb :"/account/settings", :locals => {:user => current_user}
    end

    current_user.password = params[:password]
    current_user.password_confirmation = params[:password_confirmation]
    current_user.should_change_password = false
  end
  
  if current_user.save
    flash[:user] = "Your settings have been updated."
    flash[:password] = "Your password has been changed." if params[:password].present?
    redirect "/account/settings"
  else
    erb :"account/settings", :locals => {:user => current_user}
  end
end


put '/account/phone' do
  requires_login

  current_user.phone = params[:user]['phone']
   
  if Phoner::Phone.valid?(current_user.phone) and current_user.valid?
    
    # manually set to false, in case the phone number was set and is changing
    current_user.phone_confirmed = false

    current_user.new_phone_verify_code
    current_user.save!

    SMS.deliver! "Verification Code", current_user.phone, User.phone_verify_message(current_user.phone_verify_code)

    flash[:phone] = "We've sent you a text with a verification code."
    redirect "/account/settings"
  else
    flash[:phone] = "Phone number is invalid, or taken."
    redirect "/account/settings"
  end
end

post '/account/phone/confirm' do
  requires_login

  if params[:phone_verify_code] == current_user.phone_verify_code
    current_user.phone_verify_code = nil
    current_user.phone_confirmed = true
    current_user.save!
    flash[:phone] = "Your phone number has been verified."
  else
    flash[:phone] = "Your verification code did not match. You can resend the code, if you've lost it."
  end

  redirect "/account/settings"
end

post '/account/phone/resend' do
  requires_login

  current_user.new_phone_verify_code
  current_user.save!
  SMS.deliver! "Resend Verification Code", current_user.phone, User.phone_verify_message(current_user.phone_verify_code)

  flash[:phone] = "We've sent you another verification code."
  redirect "/account/settings"
end
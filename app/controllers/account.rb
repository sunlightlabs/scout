
get '/logout' do
  log_out if logged_in?
  redirect_back_or '/'
end

get '/login' do
  @new_user = User.new
  erb :"account/login"
end

post '/login' do
  unless params[:email] and user = User.where(:email => params[:email]).first
    flash[:user] = "No account found by that email."
    redirect '/login'
  end

  if User.authenticate(user, params[:password])
    log_in user
    redirect_back_or '/'
  else
    flash.now[:user] = "Invalid password."
    @new_user = User.new
    erb :"account/login"
  end

end

post '/account/new' do
  @new_user = User.new params[:user]

  unless @new_user.password.present? and @new_user.password_confirmation.present?
    flash[:password] = "Can't use a blank password."
    redirect "/login"
  end

  if @new_user.save
    Admin.new_user @new_user
    log_in @new_user

    flash[:success] = "Your account has been created."
    redirect_back_or '/account/settings'
  else
    erb :"account/login"
  end
end

get '/account/password/forgot' do
  erb :"account/forgot"
end

post '/account/password/forgot' do
  unless params[:email] and user = User.where(:email => params[:email].strip).first
    flash[:forgot] = "No account found by that email."
    redirect "/login" and return
  end

  # issue a new reset token
  user.new_reset_token

  # email the user with a link including the token
  subject = "Request to reset your password"
  body = erb :"account/mail/reset_password", :layout => false, :locals => {:user => user}

  unless user.save and Email.deliver!("Password Reset Request", user.email, subject, body)
    flash[:forgot] = "Your account was found, but there was an error actually sending the reset password email. Try again later, or write us and we can try to figure out what happened."
    redirect "/login" and return
  end

  flash[:forgot] = "We've sent an email to reset your password."
  redirect "/login"
end


## Account management

put '/account/password/change' do
  requires_login

  

end

get '/account/password/reset' do
  unless params[:reset_token] and user = User.where(:reset_token => params[:reset_token]).first
    halt 404 and return
  end

  # reset the password itself, and the token
  new_password = user.reset_password
  user.new_reset_token
  unless user.save
    flash[:forgot] = "There was an error issuing you a new password. Please contact us for support."
    redirect "/login" and return
  end

  # send the next email with the new password

  subject = "Your password has been reset"
  body = erb :"account/mail/new_password", :layout => false, :locals => {:new_password => new_password}

  unless Email.deliver!("Password Reset", user.email, subject, body)
    flash[:forgot] = "There was an error emailing you a new password. Please contact us for support."
    redirect "/login" and return
  end

  flash[:forgot] = "Your password has been reset, and a new one has been emailed to you."
  redirect "/login"
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

get '/account/subscriptions' do
  requires_login

  erb :"account/subscriptions", :locals => {
    :interests => current_user.interests.desc(:created_at),
    :tags => current_user.tags
  }
end

put '/account/tag/:name' do
  requires_login

  name = params[:name].strip.downcase
  unless tag = current_user.tags.where(:name => name).first
    halt 404 and return
  end

  tag.attributes = params[:tag]

  if tag.save
    halt 200
  else
    halt 500
  end
end

delete "/account/tags" do
  requires_login

  names = params[:names].map {|name| Tag.deslugify name}

  names.each do |name|
    if tag = current_user.tags.where(:name => name).first
      tag.destroy
    end
  end

  redirect "/account/subscriptions"
end

get '/account/settings' do
  requires_login

  erb :"account/settings", :locals => {:user => current_user}
end


put '/account/phone' do
  requires_login

  current_user.phone = params[:user]['phone']
  if current_user.valid?
    
    # manually set to false, in case the phone number was set and is changing
    current_user.phone_confirmed = false

    current_user.new_phone_verify_code
    current_user.save!

    SMS.deliver! "Verification Code", current_user.phone, User.phone_verify_message(current_user.phone_verify_code)

    flash[:phone] = "We've sent you a text with a verification code."
    redirect "/account/settings"
  else
    flash[:phone] = "Invalid phone number."
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

# login helpers

helpers do
  def redirect_back_or(path)
    redirect(params[:redirect].present? ? params[:redirect] : path)
  end
  
  def log_in(user)
    session['user_email'] = user.email
  end
  
  def log_out
    session['user_email'] = nil
  end
end
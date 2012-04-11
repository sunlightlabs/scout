## Login/signup/forgot

get '/logout' do
  log_out if logged_in?
  redirect '/'
end

get '/login' do
  @new_user = User.new
  erb :"account/login"
end

post '/login' do
  unless params[:email] and user = User.where(:email => params[:email]).first
    flash[:user] = "No account found by that email."
    redirect_home and return
  end

  if User.authenticate(user, params[:password])
    log_in user
    redirect_home '/'
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
    redirect_home and return
  end

  if @new_user.save
    log_in @new_user

    flash[:success] = "Your account has been created. Scout at will."
    redirect_home "/account/settings"
  else
    erb :"account/login"
  end
end

post '/account/password/forgot' do
  unless params[:email] and user = User.where(:email => params[:email].strip).first
    flash[:forgot] = "No account found by that email."
    redirect_home and return
  end

  # issue a new reset token
  user.new_reset_token

  # email the user with a link including the token
  subject = "Request to reset your password"
  body = erb :"account/mail/reset_password", :layout => false, :locals => {:user => user}

  unless user.save and Email.deliver!("Password Reset Request", user.email, subject, body)
    flash[:forgot] = "Your account was found, but there was an error actually sending the reset password email. Try again later, or write us and we can try to figure out what happened."
    redirect_home and return
  end

  flash[:forgot] = "We've sent an email to reset your password."
  redirect_home
end


## Account management

put '/account/password/change' do
  requires_login

  unless User.authenticate(current_user, params[:old_password])
    flash[:password] = "Incorrect current password."
    redirect "/account/settings" and return
  end

  unless params[:password].present? and params[:password_confirmation].present?
    flash[:password] = "Can't use a blank password."
    redirect "/account/settings" and return
  end

  current_user.password = params[:password]
  current_user.password_confirmation = params[:password_confirmation]
  current_user.should_change_password = false

  if current_user.save
    flash[:password] = "Your password has been changed."
    redirect "/account/settings" and return
  else
    erb :"account/settings", :locals => {:user => current_user}
  end

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
    redirect_home and return
  end

  # send the next email with the new password

  subject = "Your password has been reset"
  body = erb :"account/mail/new_password", :layout => false, :locals => {:new_password => new_password}

  unless Email.deliver!("Password Reset", user.email, subject, body)
    flash[:forgot] = "There was an error emailing you a new password. Please contact us for support."
    redirect_home and return
  end

  flash[:forgot] = "Your password has been reset, and a new one has been emailed to you."
  redirect_home
end

put '/account/settings' do
  requires_login
  
  current_user.attributes = params[:user]
  
  if current_user.save
    halt 200
  else
    status 500
    headers["Content-Type"] = "application/json"
    {
      :error => current_user.errors.full_messages.first
    }.to_json
  end
end

get '/account/subscriptions' do
  requires_login

  erb :"account/subscriptions"
end

get '/account/settings' do
  requires_login

  erb :"account/settings", :locals => {:user => current_user}
end

# login helpers

helpers do
  def redirect_home(default = '/login')
    redirect(params[:redirect] || default)
  end
  
  def log_in(user)
    session['user_email'] = user.email
  end
  
  def log_out
    session['user_email'] = nil
  end
end
get '/logout' do
  log_out
  redirect_back_or '/'
end

get '/login' do
  # default new users on the normal login form to the Scout box being checked
  @new_user = User.new announcements: true

  erb :"account/login"
end

post '/login' do
  redirect '/login' and return unless params[:login].present?
  login = params[:login].strip

  @new_user = User.new

  if (user = User.where(email: login).first || User.by_phone(login)) and User.authenticate(user, params[:password])
    if user.service.present?
      Event.blocked_email! login, user.service
      flash.now[:login] = "This email is registered through a separate service. To use Scout, register an account under a separate email address."
      erb :"account/login"
    elsif !user.confirmed?
      flash.now[:login] = "Your account has not been confirmed."
      erb :"account/login"
    else
      log_in user
      redirect_back_or '/'
    end
  else
    flash.now[:login] = "Invalid login or password."
    erb :"account/login"
  end
end

post '/account/new' do
  if User.where(email: params[:user]['email']).first
    flash[:user] = "There is already a registered account for this email."
    redirect "/login"
  end

  @new_user = User.new
  ['email', 'password', 'password_confirmation', 'announcements', 'sunlight_announcements'].each do |field|
    @new_user.send "#{field}=", params[:user][field]
  end

  unless @new_user.password.present? and @new_user.password_confirmation.present?
    flash[:password] = "Can't use a blank password."
    redirect "/login"
  end

  # track campaign origin if possible
  if session['campaign']
    @new_user.source = session['campaign']
  end

  # auto-confirm users who go through the process this way
  @new_user.confirmed = true

  if @new_user.save
    Admin.new_user @new_user
    log_in @new_user

    flash[:success] = "Your account has been created."
    redirect_back_or '/account/settings'
  else
    erb :"account/login"
  end
end

post '/account/new/quick' do
  unless params[:email] and (params[:email] =~ User.email_format)
    halt 400, "Invalid email."
  end

  if User.where(email: params[:email]).first
    halt 400, "This email has been taken."
  end

  @new_user = User.new email: params[:email]
  @new_user.reset_password
  @new_user.confirmed = false
  @new_user.signup_process = "quick"

  # track campaign origin if possible
  if session['campaign']
    @new_user.source = session['campaign']
  end

  if @new_user.save
    Admin.new_user @new_user

    # do not log in new user, they are unconfirmed

    subject = "Confirm your email to start getting alerts"
    body = erb :"account/mail/confirm_account", layout: false, locals: {user: @new_user}
    Email.deliver!("User Confirm Email", @new_user.email, subject, body)

    halt 201
  else
    halt 400, "Unknown error."
  end
end

get '/account/confirm' do
  unless params[:confirm_token] and user = User.where(confirm_token: params[:confirm_token]).first
    halt 404 and return
  end

  # confirm user, this is good enough
  user.confirmed = true

  # reset token for good measure
  user.new_confirm_token

  user.save!

  Admin.confirmed_user user

  flash[:account] = "Your account has been confirmed. You will now receive email alerts."
  redirect "/account/settings"
end


get '/account/password/forgot' do
  erb :"account/forgot"
end

post '/account/password/forgot' do
  unless params[:email] and user = User.where(email: params[:email].strip).first and user.email.present?
    flash[:forgot] = "No account found by that email."
    redirect "/login" and return
  end

  # issue a new reset token
  user.new_reset_token

  # email the user with a link including the token
  subject = "Request to reset your password"
  body = erb :"account/mail/reset_password", layout: false, locals: {user: user}

  unless user.save and Email.deliver!("Password Reset Request", user.email, subject, body)
    flash[:forgot] = "Your account was found, but there was an error actually sending the reset password email. Try again later, or write us and we can try to figure out what happened."
    redirect "/login" and return
  end

  flash[:forgot] = "We've sent an email to reset your password."
  redirect "/login"
end

get '/account/password/reset' do
  unless params[:reset_token] and user = User.where(reset_token: params[:reset_token]).first
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
  body = erb :"account/mail/new_password", layout: false, locals: {new_password: new_password}

  unless Email.deliver!("Password Reset", user.email, subject, body)
    flash[:forgot] = "There was an error emailing you a new password. Please contact us for support."
    redirect "/login" and return
  end

  flash[:forgot] = "Your password has been reset, and a new one has been emailed to you."
  redirect "/login"
end


helpers do
  def redirect_back_or(path)
    # security vulnerability until some older browsers update
    if params[:redirect] !~ /^data\:/
      redirect(params[:redirect].present? ? params[:redirect] : path)
    end
  end

  def log_in(user)
    session['user_id'] = user.id
  end

  def log_out
    session['user_id'] = nil
  end
end
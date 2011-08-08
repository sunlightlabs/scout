#!/usr/bin/env ruby

require 'config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'

set :logging, false
set :views, 'views'
set :public, 'public'
set :sessions, true

require 'helpers'

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "helpers.rb"
  config.also_reload "models/*.rb"
end


# routes

get '/' do
  if logged_in?
    erb :dashboard
  else
    erb :index
  end
end

post '/users/new' do
  redirect '/' if params[:email].blank?
  params[:email] = params[:email].strip
  
  if user = User.where(:email => params[:email]).first
    log_in user
    flash[:success] = "Welcome back."
    redirect '/'
  else
    if user = User.create(:email => params[:email])
      log_in user
      flash[:success] = "Your account has been created."
      redirect '/'
    else
      flash.now[:failure] = "There was a problem with your email address."
      erb :index, :locals => {:email => params[:email]}
    end
  end
end

helpers do
  def logged_in?
    !current_user.nil?
  end
  
  def current_user
    @current_user ||= User.where(:email => session[:user_email]).first
  end
  
  def log_in(user)
    puts "here"
    session[:user_email] = user.email
  end
end
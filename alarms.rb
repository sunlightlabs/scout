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
  config.also_reload "subscriptions/adapters/*.rb"
  config.also_reload "subscriptions/manager.rb"
end


# routes

get '/' do
  if logged_in?
    redirect '/dashboard'
  else
    erb :index
  end
end

post '/users/new' do
  redirect '/' if params[:email].blank?
  params[:email] = params[:email].strip
  
  if user = User.where(:email => params[:email]).first
    log_in user
    redirect '/dashboard'
  else
    if user = User.create(:email => params[:email])
      log_in user
      flash[:success] = "Your account has been created."
      redirect '/dashboard'
    else
      flash.now[:failure] = "There was a problem with your email address."
      erb :index, :locals => {:email => params[:email]}
    end
  end
end

get '/logout' do
  if logged_in?
    log_out
  end
  
  redirect '/'
end


get '/dashboard' do
  requires_login
  
  subscriptions = Subscription.where(:user_id => current_user.id).desc(:created_at).all
  erb :dashboard, :locals => {:subscriptions => subscriptions}
end


post '/subscriptions' do
  requires_login
  
  subscription = Subscription.new params[:subscription]
  subscription[:user_id] = current_user.id
  
  if subscription.save
    flash[:success] = "Added subscription."
    redirect '/dashboard'
  else
    flash.now[:failure] = "Problem adding subscription."
    subscriptions = Subscription.where(:user_id => current_user.id).all
    erb :dashboard, :locals => {:subscription => subscription, :subscriptions => subscriptions}
  end
  
end

get '/subscriptions/:id/test' do
  requires_login
  
  if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    items = Subscriptions::Manager.poll subscription
    erb :results, :layout => false, :locals => {:items => items, :subscription => subscription}
  else
    halt 404
  end
end

delete '/subscriptions/:id' do
  requires_login
  
  if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    keyword = subscription.data['keyword']
    subscription.destroy
    flash[:success] = "No longer subscribed to \"#{keyword}\"."
  end
  
  redirect '/dashboard'
end

helpers do
  def logged_in?
    !current_user.nil?
  end
  
  def current_user
    @current_user ||= User.where(:email => session[:user_email]).first
  end
  
  def log_in(user)
    session[:user_email] = user.email
  end
  
  def log_out
    session[:user_email] = nil
  end
  
  def requires_login
    redirect '/' unless logged_in?
  end
end
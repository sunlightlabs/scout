#!/usr/bin/env ruby

require 'config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'

set :logging, false
set :views, 'views'
set :public, 'public'
set :sessions, true

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "helpers.rb"
  config.also_reload "models/*.rb"
  config.also_reload "subscriptions/adapters/*.rb"
  config.also_reload "subscriptions/manager.rb"
  config.also_reload "subscriptions/helpers.rb"
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
  log_out if logged_in?
  redirect '/'
end


get '/dashboard' do
  requires_login
  
  erb :dashboard, :locals => {:keywords => current_user.keywords.desc(:created_at).all.map {|k| [k, k.subscriptions]}}
end


post '/keywords' do
  requires_login

  keyword = current_user.keywords.new :keyword => params[:keyword]
  subscriptions = params[:subscription_types].map do |type| 
    current_user.subscriptions.new :keyword => params[:keyword], :subscription_type => type.to_s
  end
  
  # make sure keyword has the same validations as subscriptions
  if keyword.valid? and subscriptions.reject {|s| s.valid?}.empty?
    keyword.save!
    subscriptions.each do |subscription| 
      subscription[:keyword_id] = keyword._id
      subscription.save!
    end
    
    partial :"partials/keyword", :locals => {:keyword => keyword}
  else
    halt 500
  end
  
end

get '/search' do
  requires_login
  
  items = []
  subscribed_to = nil

  if params[:keyword_id] and (keyword = Keyword.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:keyword_id].strip)).first)
    subscribed_to = keyword.subscriptions.map {|s| s.subscription_type}
  end

  # search through every subscription type, even if it's not enabled for this search term
  # so that results are available client side
  subscription_types.keys.each do |subscription_type|
    # make new, temporary subscription items
    results = current_user.subscriptions.new(
      :keyword => params[:keyword], 
      :subscription_type => subscription_type
    ).search
    
    if results.any?
      items += results
    end
  end
  
  items = items.sort {|a, b| b.date <=> a.date}
  
  erb :results, :layout => false, :locals => {
    :items => items, 
    :subscribed_to => subscribed_to,
    :keyword => params[:keyword]
  }
end

delete '/keyword/:id' do
  requires_login
  
  if keyword = Keyword.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    subscriptions = keyword.subscriptions.to_a
    
    keyword.destroy
    subscriptions.each {|s| s.destroy}
    
    halt 200
  else
    halt 404
  end
end


# auth helpers

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
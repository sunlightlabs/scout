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
  subscriptions = subscription_types.keys.map do |type| 
    current_user.subscriptions.new :keyword => params[:keyword], :subscription_type => type.to_s
  end
  
  # make sure keyword has the same validations as subscriptions
  if keyword.valid? and subscriptions.reject {|s| s.valid?}.empty?
    keyword.save!
    subscriptions.each {|s| s.save!}
    
    redirect '/dashboard'
  else
    flash.now[:failure] = "Problem adding keyword."
    erb :dashboard, :locals => {:keyword => keyword, :keywords => current_user.keywords.all}
  end
  
end

get '/search' do
  requires_login
  
  items = []
  subscription_types.keys.each do |subscription_type|
    items += current_user.subscriptions.new(
      :keyword => params[:keyword], 
      :subscription_type => subscription_type
    ).search
  end
  
  items = items.sort {|a, b| b.date <=> a.date}
  
  erb :results, :layout => false, :locals => {:items => items, :keyword => params[:keyword]}
end

delete '/keyword/:id' do
  requires_login
  
  if keyword = Keyword.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    subscriptions = keyword.subscriptions.to_a
    
    keyword.destroy
    subscriptions.each {|s| s.destroy}
    
    flash[:success] = "No longer subscribed to \"#{keyword.keyword}\"."
  end
  
  redirect '/dashboard'
end

# delete '/subscription/:id' do
#   requires_login
#   
#   if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
#     subscription.destroy
#     halt 204
#   else
#     halt 404
#   end
# end

# post '/subscriptions' do
#   requires_login
#   
#   subscription = current_user.subscriptions.new :keyword => params[:keyword], :subscription_type => params[:subscription_type]
#   if subscription.valid?
#     subscription.save!
#     halt 201, subscription.id.to_s
#   else
#     halt 404
#   end
# end


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
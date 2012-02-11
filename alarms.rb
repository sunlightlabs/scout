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
  
  erb :dashboard, :locals => {
    :keywords => current_user.keywords.desc(:created_at).all.map {|k| [k, k.subscriptions]}
  }
end


post '/subscriptions' do
  requires_login

  phrase = params[:keyword].strip
  subscription_type = params[:subscription_type]
  new_keyword = false

  # if this is editing an existing one, find it
  if params[:keyword_id].present?
    keyword = current_user.keywords.where(:_id => BSON::ObjectId(params[:keyword_id].strip), :keyword => phrase).first
  end
  
  # default to a new one
  if keyword.nil?
    keyword = current_user.keywords.new :keyword => phrase
    new_keyword = true
  end
  
  subscription = current_user.subscriptions.new :keyword => phrase, :subscription_type => subscription_type
  
  headers["Content-Type"] = "application/json"

  # make sure keyword has the same validations as subscriptions
  if keyword.valid? and subscription.valid?
    keyword.save!
    subscription[:keyword_id] = keyword._id
    subscription.save!
    
    {
      :keyword_id => keyword._id.to_s,
      :subscription_id => subscription._id.to_s,
      :new_keyword => new_keyword,
      :pane => partial(:"partials/keyword", :locals => {:keyword => keyword})
    }.to_json
  else
    halt 500
  end
  
end

get '/search/:subscription_type' do
  requires_login
  
  keyword = params[:keyword].strip
  subscription_type = params[:subscription_type]

  results = []
  
  # make new, temporary subscription items
  results = current_user.subscriptions.new(
    :keyword => keyword,
    :subscription_type => params[:subscription_type]
  ).search
    
  # if results is nil, it usually indicates an error in one of the remote services -
  # this would be where to catch it and display something
  if results.nil?
    puts "[#{subscription_type}][#{params[:keyword]}][search] ERROR while loading this"
  end
  
  if results
    results = results.sort {|a, b| b.date <=> a.date}
  end
  
  html = erb :results, :layout => false, :locals => {
    :items => results, 
    :subscription_type => subscription_type,
    :keyword => keyword
  }

  headers["Content-Type"] = "application/json"
  
  {
    :count => (results ? results.size : -1),
    :description => "#{subscription_data[params[:subscription_type]][:search]} matching \"#{keyword}\"",
    :html => html
  }.to_json
end

# delete the subscription, and, if it's the last subscription under the keyword, delete the keyword
delete '/subscription/:id' do
  requires_login

  if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    halt 404 unless keyword = Keyword.where(:user_id => current_user.id, :_id => subscription.keyword_id).first

    deleted_keyword = false

    if keyword.subscriptions.count == 1
      keyword.destroy
      deleted_keyword = true
    end

    subscription.destroy

    headers["Content-Type"] = "application/json"
    {
      :deleted_keyword => deleted_keyword,
      :keyword_id => keyword._id.to_s
    }.to_json
  else
    halt 404
  end
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
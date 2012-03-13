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

get '/dashboard' do
  redirect '/'
end

post '/users/new' do
  redirect '/login' if params[:email].blank?
  params[:email] = params[:email].strip
  
  destination = params[:redirect] || '/'
  puts destination

  if user = User.where(:email => params[:email]).first
    log_in user
    redirect destination
  else
    user = User.new(
      :email => params[:email],
      # todo : read these from a form
      :delivery => {
        :mechanism => 'email',
        :email_frequency => 'digest'
      }
    )

    if user.save
      log_in user
      flash[:success] = "Your account has been created."
      redirect destination
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


get '/' do
  erb :index, :locals => {:interests => user_interests}
end

get '/search/:interest' do
  interest_in = params[:interest].gsub("\"", "")
  sorted_types = search_data.sort_by {|k, v| v[:order]}

  erb :search, :layout => !pjax?, :locals => {
    :types => sorted_types,
    :interest_in => interest_in,
    :interests => user_interests
  }
end

# landing page for item
# get '/:interest_type/:item_id'
get(/^\/(#{interest_data.keys.join '|'})\/([^\/]+)\/?/) do
  interest_type = params[:captures][0]
  item_id = params[:captures][1]

  interest = nil
  if logged_in?
    interest = current_user.interests.where(:in => item_id, :interest_type => interest_type).first
  end

  erb :show, :layout => !pjax?, :locals => {
    :interest_type => interest_type, 
    :item_id => item_id, 
    :interests => user_interests,
    :interest => interest
  }
end

# actual JSON data for item
# get '/:find/:interest_type/:item_id' 
get(/^\/find\/(#{interest_data.keys.join '|'})\/([^\/]+)$/) do
  interest_type = params[:captures][0]
  item_id = params[:captures][1]
  subscription_type = interest_data[interest_type][:adapter]

  unless item = Subscriptions::Manager.find(subscription_type, item_id)
    halt 404 and return
  end

  html = erb :"subscriptions/#{subscription_type}/_show", :layout => false, :locals => {
    :interest_type => interest_type, 
    :item => item
  }

  headers["Content-Type"] = "application/json"
  {
    :html => html
  }.to_json
end

post '/interest/track' do
  requires_login

  interest_type = params[:interest_type]
  item_id = params[:item_id]
  
  unless item = Subscriptions::Manager.find(interest_data[interest_type][:adapter], item_id)
    halt 404 and return
  end

  interest = current_user.interests.new :interest_type => interest_type, :in => item_id, :data => item.data

  subscriptions = interest_data[interest_type][:subscriptions].keys.map do |subscription_type|
    current_user.subscriptions.new :interest_in => item_id, :subscription_type => subscription_type
  end

  if interest.valid? and (subscriptions.reject {|s| s.valid?}.empty?)
    interest.save!
    subscriptions.each do |subscription|
      subscription[:interest_id] = interest.id
      subscription.save!
    end

    headers["Content-Type"] = "application/json"
    {
      :interest_id => interest.id.to_s,
      :pane => partial(:"partials/interest", :locals => {:interest => interest})
    }.to_json
  else
    halt 500
  end
end

get '/interest/*.*' do |interest_id, ext|
  # do not require login
  # for RSS, want readers and bots to access it freely
  # for SMS, want users on phones to see items easily without logging in

  unless interest = Interest.find(interest_id.strip)
    halt 404 and return
  end

  
  page = (params[:page] || 1).to_i
  page = 1 if page <= 0 or page > 200000000
  per_page = 20

  items = SeenItem.where(:interest_id => interest.id).desc(:date)
  items.skip(per_page * (page - 1)).limit(per_page)

  if ext == 'rss'
    headers["Content-Type"] = "application/rss+xml"
    erb :"rss", :layout => false, :locals => {
      :items => items, 
      :interest => interest,
      :url => request.url
    }
  else

  end
end

delete '/interest/untrack' do
  requires_login

  unless interest = current_user.interests.where(:_id => BSON::ObjectId(params[:interest_id].strip)).first
    halt 404 and return
  end

  subscriptions = interest.subscriptions.to_a
    
  interest.destroy
  subscriptions.each do |subscription| 
    subscription.destroy
  end
  
  halt 200
end

post '/subscriptions' do
  requires_login

  phrase = params[:interest].strip
  subscription_type = params[:subscription_type]
  new_interest = false

  # if this is editing an existing one, find it
  if params[:interest_id].present?
    interest = current_user.interests.find params[:interest_id]
  end

  # default to a new one
  if interest.nil?
    interest = current_user.interests.new :in => phrase, :interest_type => "search"
    new_interest = true
  end
  
  subscription = current_user.subscriptions.new :interest_in => phrase, :subscription_type => subscription_type
  
  headers["Content-Type"] = "application/json"

  # make sure interest has the same validations as subscriptions
  if interest.valid? and subscription.valid?
    interest.save!
    subscription[:interest_id] = interest.id
    subscription.save!
    
    {
      :interest_id => interest.id.to_s,
      :subscription_id => subscription.id.to_s,
      :new_interest => new_interest,
      :pane => partial(:"partials/interest", :locals => {:interest => interest})
    }.to_json
  else
    halt 500
  end
  
end

get '/items/:interest/:subscription_type' do
  interest_in = params[:interest].strip
  subscription_type = params[:subscription_type]

  results = []
  
  # make new, temporary subscription items
  results = Subscription.new(
    :interest_in => interest_in,
    :subscription_type => params[:subscription_type]
  ).search(:page => (params[:page] ? params[:page].to_i : 1))
    
  # if results is nil, it usually indicates an error in one of the remote services -
  # this would be where to catch it and display something
  if results.nil?
    puts "[#{subscription_type}][#{interest_in}][search] ERROR while loading this"
  end
  
  if results
    results = results.sort {|a, b| b.date <=> a.date}
  end
  
  html = erb :items, :layout => false, :locals => {
    :items => results, 
    :subscription_type => subscription_type,
    :interest_in => interest_in
  }

  headers["Content-Type"] = "application/json"
  
  {
    :count => (results ? results.size : -1),
    :description => "#{search_data[params[:subscription_type]][:search]} matching \"#{interest_in}\"",
    :html => html
  }.to_json
end

# delete the subscription, and, if it's the last subscription under the interest, delete the interest
delete '/subscription/:id' do
  requires_login

  if subscription = Subscription.where(:user_id => current_user.id, :_id => BSON::ObjectId(params[:id].strip)).first
    halt 404 unless interest = Interest.where(:user_id => current_user.id, :_id => subscription.interest_id).first

    deleted_interest = false

    if interest.subscriptions.count == 1
      interest.destroy
      deleted_interest = true
    end

    subscription.destroy

    pane = deleted_interest ? nil : partial(:"partials/interest", :locals => {:interest => interest})

    headers["Content-Type"] = "application/json"
    {
      :deleted_interest => deleted_interest,
      :interest_id => interest.id.to_s,
      :pane => pane
    }.to_json
  else
    halt 404
  end
end

delete '/interest/:id' do
  requires_login
  
  if interest = current_user.interests.where(:_id => BSON::ObjectId(params[:id].strip)).first
    subscriptions = interest.subscriptions.to_a
    
    interest.destroy
    subscriptions.each do |subscription|
      subscription.destroy
    end
    
    halt 200
  else
    halt 404
  end
end


# auth helpers

helpers do

  def pjax?
    (request.env['HTTP_X_PJAX'] or params[:_pjax]) ? true : false
  end

  def user_interests
    logged_in? ? current_user.interests.desc(:created_at).all.map {|k| [k, k.subscriptions]} : []
  end

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
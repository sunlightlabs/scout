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
    if user = User.create(:email => params[:email])
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
  erb :index, :locals => {:keywords => user_keywords}
end

get '/search/:keyword' do
  keyword_keyword = params[:keyword].gsub("\"", "")
  sorted_types = subscription_types.sort_by {|k, v| v[:order]}

  erb :search, :layout => !pjax?, :locals => {
    :types => sorted_types,
    :keyword_keyword => keyword_keyword, # a string, not a Keyword
    :keywords => user_keywords
  }
end

# landing page for item
# get '/:item_type/:item_id'
get(/^\/(#{item_data.keys.join '|'})\/([^\/]+)\/?/) do
  item_type = params[:captures][0]
  item_id = params[:captures][1]

  keyword = nil
  if logged_in?
    keyword = current_user.keywords.where(:keyword => item_id, :keyword_type => item_type).first
  end

  erb :show, :layout => !pjax?, :locals => {
    :item_type => item_type, 
    :item_id => item_id, 
    :keywords => user_keywords,
    :keyword => keyword
  }
end

# actual JSON data for item
# get '/:find/:item_type/:item_id' 
get(/^\/find\/(#{item_data.keys.join '|'})\/([^\/]+)$/) do
  item_type = params[:captures][0]
  item_id = params[:captures][1]
  subscription_type = item_data[item_type][:adapter]

  unless item = Subscriptions::Manager.find(subscription_type, item_id)
    halt 404 and return
  end

  html = erb :"subscriptions/#{subscription_type}/_show", :layout => false, :locals => {
    :item_type => item_type, 
    :item => item
  }

  headers["Content-Type"] = "application/json"
  {
    :html => html
  }.to_json
end

post '/keywords/track' do
  requires_login

  item_type = params[:item_type]
  item_id = params[:item_id]
  keyword_name = params[:keyword_name]

  unless item = Subscriptions::Manager.find(item_data[item_type][:adapter], item_id)
    halt 404 and return
  end

  keyword = current_user.keywords.new :keyword_type => item_type, :keyword => item_id, :keyword_name => keyword_name, :keyword_item => item.data

  subscriptions = item_data[item_type][:subscriptions].keys.map do |subscription_type|
    current_user.subscriptions.new :keyword => item_id, :subscription_type => subscription_type
  end

  if keyword.valid? and (subscriptions.reject {|s| s.valid?}.empty?)
    keyword.save!
    subscriptions.each do |s|
      s[:keyword_id] = keyword._id
      s.save!
    end

    headers["Content-Type"] = "application/json"
    {
      :keyword_id => keyword._id.to_s,
      :pane => partial(:"partials/keyword", :locals => {:keyword => keyword})
    }.to_json
  else
    halt 500
  end
end

get '/keyword/*.*' do |keyword_id, ext|
  # do not require login
  # for RSS, want readers and bots to access it freely
  # for SMS, want users on phones to see items easily without logging in

  unless keyword = Keyword.where(:_id => BSON::ObjectId(keyword_id.strip)).first
    halt 404 and return
  end

  
  page = (params[:page] || 1).to_i
  page = 1 if page <= 0 or page > 200000000
  per_page = 20

  items = SeenItem.where(:keyword_id => keyword.id).desc(:date)
  items.skip(per_page * (page - 1)).limit(per_page)

  if ext == 'rss'
    headers["Content-Type"] = "application/rss+xml"
    erb :"rss", :layout => false, :locals => {
      :items => items, 
      :keyword => keyword,
      :url => request.url
    }
  else

  end
end

delete '/keywords/untrack' do
  requires_login

  unless keyword = current_user.keywords.where(:_id => BSON::ObjectId(params[:keyword_id].strip)).first
    halt 404 and return
  end

  subscriptions = keyword.subscriptions.to_a
    
  keyword.destroy
  subscriptions.each do |subscription| 
    subscription.destroy
  end
  
  halt 200
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

get '/items/:keyword/:subscription_type' do
  keyword = params[:keyword].strip
  subscription_type = params[:subscription_type]

  results = []
  
  # make new, temporary subscription items
  results = Subscription.new(
    :keyword => keyword,
    :subscription_type => params[:subscription_type]
  ).search(:page => (params[:page] ? params[:page].to_i : 1))
    
  # if results is nil, it usually indicates an error in one of the remote services -
  # this would be where to catch it and display something
  if results.nil?
    puts "[#{subscription_type}][#{params[:keyword]}][search] ERROR while loading this"
  end
  
  if results
    results = results.sort {|a, b| b.date <=> a.date}
  end
  
  html = erb :items, :layout => false, :locals => {
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

    pane = deleted_keyword ? nil : partial(:"partials/keyword", :locals => {:keyword => keyword})

    headers["Content-Type"] = "application/json"
    {
      :deleted_keyword => deleted_keyword,
      :keyword_id => keyword._id.to_s,
      :pane => pane
    }.to_json
  else
    halt 404
  end
end

delete '/keyword/:id' do
  requires_login
  
  if keyword = current_user.keywords.where(:_id => BSON::ObjectId(params[:id].strip)).first
    subscriptions = keyword.subscriptions.to_a
    
    keyword.destroy
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

  def user_keywords
    logged_in? ? current_user.keywords.desc(:created_at).all.map {|k| [k, k.subscriptions]} : []
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
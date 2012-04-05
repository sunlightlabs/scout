#!/usr/bin/env ruby

require 'config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'

set :logging, false
set :views, 'views'
set :public_folder, 'public'

# disable sessions in test environment so it can be manually set
set :sessions, !test?
set :session_secret, config[:session_secret]

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "config/admin.rb"
  config.also_reload "config/email.rb"
  config.also_reload "helpers.rb"
  config.also_reload "models/*.rb"
  config.also_reload "controllers/*.rb"
  config.also_reload "subscriptions/adapters/*.rb"
  config.also_reload "subscriptions/*.rb"
  config.also_reload "deliveries/*.rb"
end

require 'controllers/users'
require 'controllers/subscriptions'
require 'controllers/feeds'

# routes

before do
  @new_user = logged_in? ? nil : User.new
  @interests = logged_in? ? current_user.interests.desc(:created_at).all.map {|k| [k, k.subscriptions]} : []
end

get '/' do
  erb :index
end

get '/search/:interest' do
  interest_in = params[:interest].gsub("\"", "")
  sorted_types = search_data.sort_by {|k, v| v[:order]}

  erb :search, :layout => !pjax?, :locals => {
    :types => sorted_types,
    :interest_in => interest_in
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
    :html => html,
    :item_url => item.find_url
  }.to_json
end

get '/items/:interest/:subscription_type' do
  interest_in = params[:interest].strip
  subscription_type = params[:subscription_type]

  params[:subscription_data] ||= {} # must default to empty hash

  # make new, temporary subscription items
  results = Subscription.new(
    :interest_in => interest_in,
    :subscription_type => params[:subscription_type],
    :data => params[:subscription_data]
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
  
  count = results ? results.size : -1
  {
    :count => count,
    :description => "#{search_data[params[:subscription_type]][:search]} matching \"#{interest_in}\"",
    :html => html,
    :search_url => (count > 0 ? results.first.search_url : nil)
  }.to_json
end


# general/auth helpers

helpers do

  def pjax?
    (request.env['HTTP_X_PJAX'] or params[:_pjax]) ? true : false
  end

  def logged_in?
    !current_user.nil?
  end
  
  def current_user
    @current_user ||= User.where(:email => session['user_email']).first
  end

  def redirect_home
    redirect(params[:redirect] || '/')
  end
  
  def log_in(user)
    session['user_email'] = user.email
  end
  
  def log_out
    session['user_email'] = nil
  end
  
  def requires_login
    redirect '/' unless logged_in?
  end
end
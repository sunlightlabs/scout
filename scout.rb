#!/usr/bin/env ruby

require 'config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'
require 'rack/file'

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
  config.also_reload "config/sms.rb"
  config.also_reload "helpers.rb"
  config.also_reload "models/*.rb"
  config.also_reload "controllers/*.rb"
  config.also_reload "subscriptions/adapters/*.rb"
  config.also_reload "subscriptions/*.rb"
  config.also_reload "deliveries/*.rb"
end

require 'controllers/api_keys'
require 'controllers/users'
require 'controllers/subscriptions'
require 'controllers/feeds'


before do
  # interest count is displayed in layout header for logged in users
  @interests = logged_in? ? current_user.interests.desc(:created_at).all.map {|k| [k, k.subscriptions]} : []
end


get '/' do
  erb :index
end

# search results

get '/search/:subscriptions/:query' do
  query = params[:query].gsub("\"", "")

  # subscriptions_map = {}

  subscriptions = params[:subscriptions].split(",").map do |slug|
    subscription_type, index = slug.split "-"
    next unless search_adapters.keys.include?(subscription_type)

    Subscription.new(
      :interest_in => query,
      :subscription_type => subscription_type,
      :data => (params[slug] || {}),
      :slug => slug
    )
  end.compact

  halt 404 and return unless subscriptions.any?

  erb :"search/search", :layout => !pjax?, :locals => {
    :subscriptions => subscriptions,
    :query => query
  }
end

get '/fetch/search/:subscription_type/:query' do
  query = params[:query].strip
  subscription_type = params[:subscription_type]

  data = params[subscription_type] || {} # must default to empty hash

  subscription = Subscription.new(
    :subscription_type => subscription_type,
    :interest_in => query,
    :data => data
  )

  page = params[:page].present? ? params[:page].to_i : 1
  per_page = params[:per_page].present? ? params[:per_page].to_i : nil

  # perform the remote search, pass along pagination preferences
  results = subscription.search :page => page, :per_page => per_page
    
  # if results is nil, it usually indicates an error in one of the remote services
  if results.nil?
    puts "[#{subscription_type}][#{interest_in}][search] ERROR while loading this"
  end
  
  # if results
  #   results = results.sort {|a, b| b.date <=> a.date}
  # end
  
  html = erb :"search/items", :layout => false, :locals => {
    :items => results, 
    :subscription => subscription,
    :query => query,
    :sole => (per_page > 5)
  }

  headers["Content-Type"] = "application/json"
  
  count = results ? results.size : -1
  {
    :count => count,
    :html => html,

    # TODO: don't return this at all unless it's in developer mode (a non-system API key in use)
    :search_url => (count > 0 ? results.first.search_url : nil)
  }.to_json
end


# landing pages

get "/item/:interest_type/:item_id" do
  interest_type = params[:interest_type].strip
  item_id = params[:item_id].strip

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

get "/fetch/item/:interest_type/:item_id" do
  interest_type = params[:interest_type].strip
  item_id = params[:item_id].strip
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

  def requires_login
    redirect '/' unless logged_in?
  end

end

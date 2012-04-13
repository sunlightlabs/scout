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

get '/faq' do
  erb :faq
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

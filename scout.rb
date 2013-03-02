#!/usr/bin/env ruby

require './config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'
require 'rack/file'

set :logging, false
set :views, 'app/views'
set :public_folder, 'public'

# disable sessions in test environment so it can be manually set
unless test?
  use Rack::Session::Cookie, :key => 'rack.session',
    :path => '/',
    :expire_after => (60 * 60 * 24 * 30), # 30 days
    :secret => config[:session_secret]
end

# TODO: seriously?
disable :protection

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "./config/environment.rb"
  config.also_reload "./config/admin.rb"
  config.also_reload "./config/email.rb"
  config.also_reload "./config/sms.rb"
  config.also_reload "./app/helpers/*.rb"
  config.also_reload "./app/models/*.rb"
  config.also_reload "./app/controllers/*.rb"
  config.also_reload "./subscriptions/adapters/*.rb"
  config.also_reload "./subscriptions/*.rb"
  config.also_reload "./deliveries/*.rb"
end

Dir.glob("./app/controllers/*.rb").each {|filename| load filename}


before do
  # interest count is displayed in layout header for logged in users
  @interests = logged_in? ? current_user.interests.desc(:created_at).all.map {|k| [k, k.subscriptions]} : []

  # lightweight server-side campaign conversion tracking 
  [:utm_source, :utm_medium, :utm_content, :utm_campaign].each do |campaign|
    if params[campaign].present?
      session['campaign'] ||= {}
      session['campaign'][campaign] = params[campaign]
    end
  end
end


get '/' do
  erb :index
end

get '/about' do
  erb :about
end

get '/error' do
  raise Exception.new("KABOOM.")
end

not_found do
  erb :"404"
end

error do
  exception = env['sinatra.error']
  name = exception.class.name
  message = exception.message
  request = {method: env['REQUEST_METHOD'], url: env['REQUEST_URI']}
  
  if current_user
    request[:user] = current_user.id.to_s
  end

  Admin.report Report.exception("Exception Notifier", "#{name}: #{message}", exception, request: request)
  erb :"500"
end


helpers do

  def pjax?
    (request.env['HTTP_X_PJAX'] or params[:_pjax]) ? true : false
  end

  def logged_in?
    !current_user.nil?
  end
  
  def current_user
    @current_user ||= (session['user_id'] ? User.find(session['user_id']) : nil)
  end

  def requires_login(path = '/')
    redirect path unless logged_in?
  end

  # done as the end of an endpoint
  def json(code, object)
    headers["Content-Type"] = "application/json"
    status code
    object.to_json
  end

  def load_user
    user_id = params[:user_id].strip
    if user = User.where(username: user_id).first
      user
    else # can be nil
      User.find user_id
    end
  end

end
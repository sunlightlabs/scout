#!/usr/bin/env ruby

require 'config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'

require 'helpers'


set :logging, false
set :views, 'views'
set :public, 'public'

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "models/*.rb"
end


# routes

get '/' do
  erb :index
end


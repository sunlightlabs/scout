#!/usr/bin/env ruby

require 'config/environment'

set :logging, false

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "models/*.rb"
end

get '/' do
  'home'
end
require 'sinatra'
require 'mongoid'
require 'tzinfo'

def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end

configure do
  config[:mongoid][:logger] = Logger.new config[:log_file] if config[:log_file]
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
end

Dir.glob('models/*.rb').each {|filename| load filename}
Dir.glob('subscriptions/adapters/*.rb').each {|filename| load filename}
require 'subscriptions/manager'
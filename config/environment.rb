# intricate include order because of JSON serialization

require 'json/ext'

# hack to stop ActiveSupport from taking away my JSON C extension
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json_from_gem, :to_json
  end
end

require 'sinatra'
require 'mongoid'
require 'tzinfo'
require 'twilio-rb'

# restore the original to_json on core objects (damn you ActiveSupport)
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json, :to_json_from_gem
  end
end


def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end

def subscription_map
  @subscription_map ||= YAML.load_file File.join(File.dirname(__FILE__), "../subscriptions/subscriptions.yml")
end

configure do
  Mongoid.load! "config/mongoid.yml"
  
  if config[:twilio]
    Twilio::Config.setup(
      :account_sid => config[:twilio][:account_sid],
      :auth_token => config[:twilio][:auth_token]
    )
  end
end

require 'mongoid/slug'
Dir.glob('app/models/*.rb').each {|filename| load filename}

# helpers
require 'padrino-helpers'
Dir.glob('app/helpers/*.rb').each {|filename| load filename}
helpers Padrino::Helpers
helpers Helpers::General
helpers Helpers::Subscriptions
helpers Helpers::Routing

# transmission mechanisms (Twilio, pony, postmark, "fake")
require './config/email'
require './config/sms'

# admin messages and reports
require './config/admin'

# delivery management and mechanisms
Dir.glob('deliveries/*.rb').each {|filename| load filename}

# subscription management and adapters
Dir.glob('subscriptions/adapters/*.rb').each {|filename| load filename}
require './subscriptions/manager'

# convenience functions for sections of the subscriptions map
def interest_data
  subscription_map['interest_data']
end

def search_adapters
  subscription_map['search_adapters']
end

def interest_adapters
  subscription_map['item_adapters']
end

def search_types
  subscription_map['search_display_order']
end
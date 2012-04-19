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
require 'padrino-helpers'

# restore the original to_json on core objects (damn you ActiveSupport)
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json, :to_json_from_gem
  end
end




def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
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

# app-wide models and helpers
Dir.glob('models/*.rb').each {|filename| load filename}
require './helpers'

# admin messages and reports
require './config/admin'

# delivery mechanisms (Twilio, pony, postmark, "fake")
require './config/email'
require './config/sms'

# delivery management and mechanisms
Dir.glob('deliveries/*.rb').each {|filename| load filename}

# subscription management and adapters
Dir.glob('subscriptions/adapters/*.rb').each {|filename| load filename}
require './subscriptions/manager'

# maps types of items to the subscription adapter they can be found with
def interest_data
  {
    'bill' => {
      :adapter => "federal_bills",
      :subscriptions => {
        'federal_bills_activity' => {
          :name => "Activity"
        },
        'federal_bills_upcoming_floor' => {
          :name => "Floor Schedule"
        }
      }
    },
    'state_bill' => {
      :adapter => "state_bills",
      :subscriptions => {
        'state_bills_activity' => {
          :name => "Activity"
        },
        'state_bills_votes' => {
          :name => "Votes"
        }
      }
    },
    'regulation' => {
      :adapter => "regulations"
    },
    'speech' => {
      :adapter => "speeches"
    }
  }
end

# adapters used to process keyword searches,
# and the item type they search over
def search_adapters
  {
    'federal_bills' => 'bill',
    'state_bills' => 'state_bill',
    'speeches' => 'speech',
    'regulations' => 'regulation'
  }
end

def interest_adapters
  {
    'federal_bills_activity' => 'bill',
    'federal_bills_upcoming_floor' => 'bill',
    'state_bills_votes' => 'state_bill',
    'state_bills_activity' => 'state_bill'
  }
end
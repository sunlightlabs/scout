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


# needed all over the app - might as well just make a global module

module ScoutUtils

  def self.state_map
    @state_map ||= {
      "AL" => "Alabama",
      "AK" => "Alaska",
      "AZ" => "Arizona",
      "AR" => "Arkansas",
      "CA" => "California",
      "CO" => "Colorado",
      "CT" => "Connecticut",
      "DE" => "Delaware",
      "DC" => "District of Columbia",
      "FL" => "Florida",
      "GA" => "Georgia",
      "HI" => "Hawaii",
      "ID" => "Idaho",
      "IL" => "Illinois",
      "IN" => "Indiana",
      "IA" => "Iowa",
      "KS" => "Kansas",
      "KY" => "Kentucky",
      "LA" => "Louisiana",
      "ME" => "Maine",
      "MD" => "Maryland",
      "MA" => "Massachusetts",
      "MI" => "Michigan",
      "MN" => "Minnesota",
      "MS" => "Mississippi",
      "MO" => "Missouri",
      "MT" => "Montana",
      "NE" => "Nebraska",
      "NV" => "Nevada",
      "NH" => "New Hampshire",
      "NJ" => "New Jersey",
      "NM" => "New Mexico",
      "NY" => "New York",
      "NC" => "North Carolina",
      "ND" => "North Dakota",
      "OH" => "Ohio",
      "OK" => "Oklahoma",
      "OR" => "Oregon",
      "PA" => "Pennsylvania",
      "PR" => "Puerto Rico",
      "RI" => "Rhode Island",
      "SC" => "South Carolina",
      "SD" => "South Dakota",
      "TN" => "Tennessee",
      "TX" => "Texas",
      "UT" => "Utah",
      "VT" => "Vermont",
      "VA" => "Virginia",
      "WA" => "Washington",
      "WV" => "West Virginia",
      "WI" => "Wisconsin",
      "WY" => "Wyoming"
    }
  end
end
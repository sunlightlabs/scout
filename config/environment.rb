require 'sinatra'
require 'mongoid'
require 'tzinfo'
require 'twilio-rb'
require 'padrino-helpers'

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
require 'helpers'

# admin messages and reports
require 'config/admin'

# email sending wrapper (pony or postmark)
require 'config/email'

# delivery management and mechanisms
Dir.glob('deliveries/*.rb').each {|filename| load filename}

# subscription management and adapters
Dir.glob('subscriptions/adapters/*.rb').each {|filename| load filename}
require 'subscriptions/manager'

# maps types of items to the subscription adapter they can be found with
def interest_data
  {
    'bill' => {
      :name => "Bill",
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
      :name => "State Bill",
      :adapter => "state_bills",
      :subscriptions => {
        'state_bills_activity' => {
          :name => "Activity"
        },
        'state_bills_votes' => {
          :name => "Votes"
        }
      }
    }
  }
end

# maps each type of subscription adapter to their display information
def search_data
  data = {
    'federal_bills' => {
      :name => "Congressional Bills",
      :search => "Bills in Congress",
      :order => 1
    },
    'state_bills' => {
      :name => "State Bills",
      :search => "Bills in the states",
      :order => 3,
      :filter => true
    },
    'congressional_record' => {
      :name => "Congressional Speeches",
      :search => "Speeches from Congress",
      :order => 2
    },
    'regulations' => {
      :name => "Federal Regulations",
      :search => "Federal regulations",
      :order => 4
    },
    'committee_hearings' => {
      :name => "Senate Hearings",
      :search => "Senate hearings",
      :order => 5
    },
    'gao_reports' => {
      :name => "GAO Reports",
      :search => "GAO reports",
      :order => 6
    }
  }
  
  if config[:hide_subscription_types]
    config[:hide_subscription_types].each do |type|
      data.delete type.to_s
    end
  end

  data
end
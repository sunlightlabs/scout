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

# app-wide models and helpers
Dir.glob('models/*.rb').each {|filename| load filename}
require 'helpers'

# email utilities
require 'config/email'

# subscription-specific adapters and management
Dir.glob('subscriptions/adapters/*.rb').each {|filename| load filename}
require 'subscriptions/manager'
require 'subscriptions/deliverance'

# maps types of items to the subscription adapter they can be found with
def interest_data
  {
    'bill' => {
      :name => "Bill",
      :adapter => "federal_bills",
      :subscriptions => {
        'federal_bills_activity' => {
          :name => "Legislative Activity",
          :description => ""
        },
        'federal_bills_upcoming_floor' => {
          :name => "Upcoming Floor Appearances",
          :description => ""
        }
      }
    },
    # 'state_bill' => {
    #   :name => "State Bill",
    #   :adapter => "state_bills",
    #   :subscriptions => {
    #     'state_bills_activity' => {
    #       :name => "Legislative Activity",
    #       :description => ""
    #     }
    #   }
    # }
  }
end

# maps each type of subscription adapter to their display information
def search_data
  data = {
    'federal_bills' => {
      :name => "Congressional Bills",
      :description => "bill(s) in Congress",
      :search => "Bills in Congress",
      :item => 'bill',
      :order => 1
    },
    'state_bills' => {
      :name => "State Bills",
      :description => "state bill(s)",
      :search => "Bills in the states",
      :order => 3
    },
    'congressional_record' => {
      :name => "Congressional Speeches",
      :description => "speech(es)",
      :search => "Speeches from Congress",
      :order => 2
    },
    'regulations' => {
      :name => "Federal Regulations",
      :description => "regulation(s)",
      :search => "Federal regulations",
      :order => 4
    },
    'committee_hearings' => {
      :name => "Senate Committee Hearings",
      :description => "hearing(s)",
      :search => "Senate hearings",
      :order => 5
    },
    'gao_reports' => {
      :name => "GAO Reports",
      :description => "GAO report(s)",
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
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

def subscription_data 
  {
    'federal_bills' => {
      :name => "Congressional Bills",
      :description => "bill(s) in Congress",
      :group => "congress",
      :order => 1
    },
    'state_bills' => {
      :name => "State Bills",
      :description => "state bill(s)",
      :group => "states",
      :order => 3
    },
    'congressional_record' => {
      :name => "Congressional Speeches",
      :description => "speech(es)",
      :group => "congress",
      :order => 2
    },
    'regulations' => {
      :name => "Federal Regulations",
      :description => "regulation(s)",
      :group => "regulations",
      :order => 4
    }
  }
end
require 'sinatra'
require 'mongoid'

require 'tzinfo'
require 'twilio-rb'
require 'feedbag'
require 'phone'


def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end

def subscription_map
  @subscription_map ||= YAML.load_file File.join(File.dirname(__FILE__), "../subscriptions/subscriptions.yml")
end

# words not allowed to be usernames, very inclusive to preserve flexibility in routing
def reserved_names
  if @reserved_names
    @reserved_names
  else
    names = %w{
      user account subscription interest item fetch
      ajax pjax tag seen delivery receipt report email route
      sms admin login logout session signup signout request response
      server client rss feed atom json xml search api api_key import 
      export download upload favicon index about privacy_policy privacy 
      terms legal contact username slug name 
      
      bill state_bill regulation speech document hearing update floor_update
      rule uscode cfr report
    }
    @reserved_names = names + names.map(&:pluralize)
  end
end

configure do
  # default country code for phone numbers
  Phoner::Phone.default_country_code = '1'

  Mongoid.load! "config/mongoid.yml"
  
  if config[:twilio]
    Twilio::Config.setup(
      :account_sid => config[:twilio][:account_sid],
      :auth_token => config[:twilio][:auth_token]
    )
  end

  # if a consistent time zone is needed, use Eastern Time
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"
end

# models
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

def search_adapters
  if @search_adapters
    @search_adapters
  else 
    @search_adapters = {}
    subscription_map['search_adapters'].map {|h| [h.keys.first, h.values.first]}.each do |adapter, item_type|
      @search_adapters[adapter] = item_type
    end
    @search_adapters
  end
end

def item_adapters
  @item_adapters ||= subscription_map['item_adapters']
end

def search_types
  @search_types ||= subscription_map['search_adapters'].map {|h| h.keys.first}
end

# hardcoded for now
def cite_types
  ["federal_bills", "regulations", "documents"]
end

def item_types
  if @item_types
    @item_types
  else
    @item_types = {}
    search_adapters.each do |adapter, item_type|
      @item_types[item_type] ||= {}
      @item_types[item_type]['adapter'] = adapter
    end
    item_adapters.each do |adapter, item_type|
      @item_types[item_type] ||= {}
      @item_types[item_type]['subscriptions'] ||= []
      @item_types[item_type]['subscriptions'] << adapter
    end
    @item_types
  end
end
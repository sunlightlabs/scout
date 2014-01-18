require 'sinatra'
require 'mongoid'
require 'mongoid_paperclip'

require 'safe_yaml' # we only use yaml for config, but just in case, sanitize
require 'escape_utils'

require 'tzinfo'
require 'twilio-rb'
require 'feedbag'
require 'phone'

require 'asset_sync'


class Environment
  def self.services
    @services ||= YAML.safe_load_file File.join(File.dirname(__FILE__), "services.yml")
  end

  def self.config
    @config ||= YAML.safe_load_file File.join(File.dirname(__FILE__), "config.yml")
  end

  # my own slugifier (wildly more performant than the all-Ruby solutions I found)
  def self.to_url(string)
    string = string.dup
    string.gsub! /[^\w\-\s]+/, ""
    string.gsub! /\s+/, '-'
    string.downcase!
    string[0..200]
  end

  def self.asset_path(path)
    if config['assets'] && config['assets']['enabled']
      File.join Environment.config['assets']['asset_host'], "assets", path
    else
      File.join "/assets", path
    end
  end
end

def subscription_map
  @subscription_map ||= YAML.safe_load_file File.join(File.dirname(__FILE__), "../subscriptions/subscriptions.yml")
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
      terms legal contact username slug name error exception tos terms_of_service
      a b c d e f g h i j k l m n o p q r s t u v w x y z

      bill state_bill regulation speech document hearing update floor_update
      rule uscode cfr report
    }
    @reserved_names = names + names.map(&:pluralize) + names.map(&:upcase) + names.map(&:capitalize)
  end
end

configure do
  # ensure YAML files get loaded with naive processing
  SafeYAML::OPTIONS[:default_mode] = :safe

  # this isn't used anywhere, we're setting it to avoid deprecation warnings
  I18n.enforce_available_locales = true

  # default country code for phone numbers
  Phoner::Phone.default_country_code = '1'

  Mongoid.configure do |c|
    c.load_configuration Environment.config['mongoid'][Sinatra::Base.environment.to_s]
  end

  if Environment.config['twilio']
    Twilio::Config.setup(
      account_sid: Environment.config['twilio']['account_sid'],
      auth_token: Environment.config['twilio']['auth_token']
    )
  end

  # if a consistent time zone is needed, use Eastern Time
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"


  assets = Environment.config['assets']
  AssetSync.configure do |config|

    if assets && assets['enabled'] && assets['s3']
      config.fog_provider = 'AWS'
      config.fog_directory = assets['s3']['bucket']
      config.aws_access_key_id = assets['s3']['access_key']
      config.aws_secret_access_key = assets['s3']['secret_key']

      config.prefix = "assets"
      config.public_path = Pathname('./public')

      config.fail_silently = false
      config.existing_remote_files = 'ignore'

      config.gzip_compression = true
    else
      # puts "Asset syncing disabled, using local assets."
      config.enabled = false
    end
  end
end


# models
Dir.glob('app/models/**/*.rb').each {|filename| load filename}

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

    item_types.each do |item_type, info|
      if search_adapter = info['adapter']
        @search_adapters[search_adapter] = item_type
      end
    end

    @search_adapters
  end
end

def item_adapters
  if @item_adapters
    @item_adapters
  else
    @item_adapters = {}

    item_types.each do |item_type, info|
      if subscriptions = info['subscriptions']
        subscriptions.each do |subscription_type|
          @item_adapters[subscription_type] = item_type
        end
      end
    end

    @item_adapters
  end
end

def item_types
  @item_types ||= subscription_map['item_types']
end

# hardcoded for now
def search_types
  ["federal_bills", "court_opinions", "regulations", "state_bills", "documents", "speeches"]
end

# cache the constantized stuff (this is dumb, this all needs to be refactored)
def adapter_map
  if @adapter_map
    @adapter_map
  else
    @adapter_map = {}
    adapters = Dir.glob File.join(File.dirname(__FILE__), "../subscriptions/adapters/*.rb")
    adapters.each do |adapter|
      type = File.basename adapter, ".rb"
      @adapter_map[type] = "Subscriptions::Adapters::#{type.camelize}".constantize
    end
    @adapter_map
  end
end

def cite_types
  ["federal_bills", "regulations", "documents"]
end

# warm caches (ugh)
adapter_map
item_adapters
search_adapters
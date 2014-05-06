require 'sinatra'
require 'sinatra/cross_origin'
require 'mongoid'
require 'mongoid_paperclip'

require 'raven'

require 'safe_yaml'
require 'escape_utils'

require 'tzinfo'
require 'feedbag'

require 'asset_sync'

set :adapter_path, ENV.fetch('SCOUT_ADAPTER_PATH', './subscriptions/adapters')

class Environment

  # loaded at start time, needs restart to turn on/off
  def self.downtime?
    config['downtime'] == true
  end

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
    if config['assets'] and config['assets']['enabled']
      File.join Environment.config['assets']['asset_host'], "assets", path
    else
      File.join "/assets", path
    end
  end
end

# words not allowed to be usernames, very inclusive to preserve flexibility in routing
def reserved_names
  if @reserved_names
    @reserved_names
  else
    names = %w{
      user account subscription interest item fetch
      ajax pjax tag seen delivery receipt report email route
      admin login logout session signup signout request response
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
  SafeYAML::OPTIONS[:default_mode] = :safe

  # this isn't used anywhere, we're setting it to avoid deprecation warnings
  I18n.enforce_available_locales = true

  Mongoid.configure do |c|
    c.load_configuration Environment.config['mongoid'][Sinatra::Base.environment.to_s]
  end

  # if a consistent time zone is needed, use Eastern Time
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"

  # Sentry for exception handling
  if Environment.config['sentry'].present?
    # only output actual things
    logger = ::Logger.new(STDOUT)
    logger.level = ::Logger::WARN

    Raven.configure do |config|
      config.dsn = Environment.config['sentry']
      config.ssl_verification = true
      config.environments = ['production']
      config.tags = {environment: Sinatra::Base.environment}
      config.logger = logger
    end
  end

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

# email transports, and admin messages/reports
require './config/email'
require './config/slack'
require './config/admin'

# delivery manager and email assembler
Dir.glob('deliveries/*.rb').each {|filename| load filename}

# subscription management and adapters
Dir.glob(File.join(settings.adapter_path, "*.rb")).each {|filename| load filename}
require './subscriptions/manager'


# convenience functions for sections of the subscriptions map

def search_adapters
  @search_adapters ||= {}.tap do |hash|
    adapter_info.each do |adapter,info|
      if info[:search_adapter] && info[:item_type]
        hash[adapter] = info[:item_type]
      end
    end
  end
end

def item_adapters
  @item_adapters ||= {}.tap do |hash|
    adapter_info.each do |adapter,info|
      if info[:item_adapter] && info[:item_type]
        hash[adapter] = info[:item_type]
      end
    end
  end
end

def adapter_info
  @adapter_info ||= begin
    hash = {}

    Subscriptions::Adapters.constants.each do |symbol|
      klass = Subscriptions::Adapters.const_get(symbol)
      hash[symbol.to_s.underscore] = {
        klass: klass,
        # One of "bill", "document", "opinion", "regulation", "speech", "state_bill", "state_legislator" or nil.
        item_type: klass.const_defined?(:ITEM_TYPE) ? klass::ITEM_TYPE : nil,
        # Either `true` or `false`.
        search_adapter: klass.const_defined?(:SEARCH_ADAPTER) ? klass::SEARCH_ADAPTER : false,
        # Either `true` or `false`.
        item_adapter: klass.const_defined?(:ITEM_ADAPTER) ? klass::ITEM_ADAPTER : false,
        # Either `true` or `false`.
        search_type: klass.const_defined?(:SEARCH_TYPE) ? klass::SEARCH_TYPE : false,
        # Either `true` or `false`.
        cite_type: klass.const_defined?(:CITE_TYPE) ? klass::CITE_TYPE : false,
        # An integer.
        sort_weight: klass.const_defined?(:SORT_WEIGHT) ? klass::SORT_WEIGHT : Float::INFINITY,
      }
    end

    Hash[hash.sort_by{|_,info| info[:sort_weight]}]
  end
end

def item_types
  @item_types ||= {}.tap do |hash|
    adapter_info.each do |adapter,info|
      if info[:item_type]
        hash[info[:item_type]] ||= {'subscriptions' => []}
        if info[:search_adapter]
          hash[info[:item_type]]['adapter'] = adapter
        elsif info[:item_adapter]
          hash[info[:item_type]]['subscriptions'] << adapter
        end
      end
    end
  end
end

def search_types
  adapter_info.select{|_,info| info[:search_type]}.keys
end

def cite_types
  adapter_info.select{|_,info| info[:cite_type]}.keys
end

# cache the constantized stuff (this is dumb, this all needs to be refactored)
def adapter_map
  @adapter_map ||= {}.tap do |hash|
    adapter_info.each do |adapter,info|
      hash[adapter] = info[:klass]
    end
  end
end

# warm caches (ugh)
adapter_map
item_adapters
search_adapters

source 'https://rubygems.org'

gem 'oj'
gem 'multi_json'
gem 'curb'
gem 'safe_yaml' # avoids problems with YAML vulnerabilities, but no symbol keys

gem 'sinatra', '~> 1.4'
gem 'sinatra-contrib', '~> 1.4'
gem 'sinatra-flash'

gem 'padrino-helpers', '~> 0.11'
gem 'rinku'
gem 'escape_utils'

gem "mongoid", '~> 3.1'
gem "mongoid-paperclip", require: "mongoid_paperclip"

# asset syncing to S3
gem "aws-sdk"
gem 'asset_sync'
gem "unf"

gem 'ruby-hmac'
gem 'bcrypt'

# detect gov't and educational email addresses
gem 'gman'
gem 'swot'

gem 'postmark', '~> 1.0'
gem 'pony', '~> 1.4'

gem 'rack', '~> 1.5'
gem 'rack-ssl'
gem 'rake'

gem 'big_sitemap'

group :development do
  gem 'wirb'
  gem 'paint'
  gem 'unicorn'
#  gem 'rblineprof'
#  gem 'rack-lineprof'
end

group :test do
  gem 'rack-test'
  gem 'rspec-mocks', '~> 2.14' # 3.X would need refactoring
  gem 'timecop', '~> 0.7'
  gem 'factory_girl'
end

# feed parsing and discovery
gem 'feedjira'
gem 'feedbag'
gem 'sanitize'

# advanced search string parsing
gem 'lucene_query_parser', git: 'git://github.com/sunlightlabs/lucene_query_parser.git'
ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'test/unit'

require 'bundler/setup'
require 'rack/test'

require './scout'
require './test/factories'

require 'rspec/mocks'

set :environment, :test

module TestHelper

  module Methods

    # Test::Unit hooks

    def setup
      RSpec::Mocks.setup(self)

      HTTParty.stub(:get).and_return({})
      Feedbag.stub(:find).and_return([])
    end

    def verify
      RSpec::Mocks.space.verify_all
    end

    def teardown
      User.destroy_all
      ApiKey.destroy_all
      
      Interest.destroy_all
      Subscription.destroy_all
      
      Delivery.destroy_all
      Receipt.destroy_all

      # remove rspec mocks
      RSpec::Mocks.space.reset_all
    end


    # mock helpers for faking remote content

    def mock_response(url, fixture)
      file = "test/fixtures/#{fixture}.json"
      response = MultiJson.load(open file)
      HTTParty.should_receive(:get).with(url).and_return response
    end

    def mock_search(subscription, function = :search)
      fixture = "#{subscription.subscription_type}/search/#{subscription.interest_in}"
      url = subscription.adapter.url_for subscription, function, {}
      mock_response url, fixture
    end

    def mock_item(item_id, item_type)
      subscription_type = item_types[item_type]['adapter']
      fixture = "#{subscription_type}/item/#{item_id}"
      url = Subscription.adapter_for(subscription_type).url_for_detail item_id
      mock_response url, fixture
    end


    # Sinatra helpers

    def app
      Sinatra::Application
    end

    def login(user)
      {"rack.session" => {'user_email' => user.email}}
    end


    # custom helpers

    def redirect_path
      last_response.headers['Location'].sub(/http:\/\/example.org/, '')
    end

    def assert_response(status)
      assert_equal status, last_response.status
    end

    def assert_redirect(path)
      assert_response 302
      assert_equal path, redirect_path
    end

    def json_response
      JSON.parse last_response.body
    end

  end
end
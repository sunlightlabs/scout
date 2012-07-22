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


    # factory for interests

    def search_interest!(user, search_type = "all", interest_in = "foia", data = {}, attributes = {})
      # have to be explicit about these things now
      data['query'] ||= interest_in
      data['query_type'] ||= 'simple'
      original_in = interest_in

      interest = Interest.for_search user, search_type, interest_in, original_in, data
      interest.attributes = attributes
      interest.save!
      interest
    end


    # mock helpers for faking remote content

    def mock_response(url, fixture)
      file = "test/fixtures/#{fixture}.json"
      
      if File.exists?(file)
        response = MultiJson.load(open file)
      else
        response = nil
      end

      HTTParty.should_receive(:get).with(url).and_return response
    end

    def mock_search(subscription, function = :search)
      fixture = "#{subscription.subscription_type}/#{subscription.interest_in}/#{function}"
      url = subscription.adapter.url_for subscription, function, {}
      mock_response url, fixture
    end

    def mock_item(item_id, item_type)
      subscription_type = item_types[item_type]['adapter']
      fixture = "#{subscription_type}/item/#{item_id}"
      url = Subscription.adapter_for(subscription_type).url_for_detail item_id
      mock_response url, fixture
    end

    # helper helpers
    class Anonymous; extend Helpers::Routing; end
    def routing; Anonymous; end


    # Sinatra helpers

    def app
      Sinatra::Application
    end

    def login(user)
      {"rack.session" => {'user_id' => user.id.to_s}}
    end

    def session(hash = {})
      {"rack.session" => hash}
    end

    # custom helpers

    def redirect_path
      if last_response.headers['Location']
        last_response.headers['Location'].sub(/http:\/\/example.org/, '')
      else
        nil
      end
    end

    def assert_response(status, message = nil)
      assert_equal status, last_response.status, (message || last_response.body)
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
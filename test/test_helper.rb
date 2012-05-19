ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'test/unit'

require 'bundler/setup'
require 'rack/test'

require './scout'
require './test/factories/factories'

require 'rspec/mocks'

set :environment, :test

module TestHelper

  module Methods

    # Test::Unit hooks

    def setup
      RSpec::Mocks.setup(self)

      Subscriptions::Manager.stub(:poll).and_return([])
      Subscriptions::Manager.stub(:find).and_return(double(:data => {}))
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


    # Sinatra helpers

    def app
      Sinatra::Application
    end

    def login(user)
      {"rack.session" => {'user_email' => user.email}}
    end


    def new_user!(options = {})
      User.create!({:email => "fake@example.com", :password => "test", :password_confirmation => "test"}.merge(options))
    end

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
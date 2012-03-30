module TestHelper

  module Methods

    # Test::Unit hooks

    def setup
      RSpec::Mocks.setup(self)
    end

    def verify
      RSpec::Mocks.space.verify_all
    end

    def teardown
      # delete fake user if it was created
      User.where(:test_account => true).delete_all

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
      User.create!({:test_account => true, :email => "fake@example.com", :password => "test", :password_confirmation => "test"}.merge(options))
    end

    def redirect_path
      last_response.headers['Location'].sub(/http:\/\/example.org/, '')
    end
  end
end
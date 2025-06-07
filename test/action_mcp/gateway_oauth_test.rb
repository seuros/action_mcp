# frozen_string_literal: true

require "test_helper"

class ActionMCP::GatewayOAuthTest < ActiveSupport::TestCase
  def setup
    @original_config = ActionMCP.configuration
    ActionMCP.instance_variable_set(:@configuration, nil)
  end

  def teardown
    ActionMCP.instance_variable_set(:@configuration, @original_config)
  end

  test "oauth_enabled? checks configuration" do
    gateway = ActionMCP::Gateway.new

    # OAuth not in auth methods
    ActionMCP.configure do |config|
      config.authentication_methods = [ "jwt" ]
      config.oauth_config = { "provider" => "test" }
    end
    refute gateway.send(:oauth_enabled?)

    # OAuth in auth methods but no config
    ActionMCP.configure do |config|
      config.authentication_methods = [ "oauth" ]
      config.oauth_config = {}
    end
    refute gateway.send(:oauth_enabled?)

    # OAuth in auth methods with config
    ActionMCP.configure do |config|
      config.authentication_methods = [ "oauth" ]
      config.oauth_config = { "provider" => "test" }
    end
    assert gateway.send(:oauth_enabled?)
  end

  test "authentication method selection" do
    ActionMCP.configure do |config|
      config.authentication_methods = [ "none" ]
    end

    gateway = ActionMCP::Gateway.new

    # Test that none authentication is attempted
    def gateway.default_user_identity
      { user: User.new(id: 1, email: "test@example.com") }
    end

    def gateway.find_or_create_default_user
      User.new(id: 1, email: "test@example.com")
    end

    result = gateway.send(:authenticate!)
    assert_equal 1, result[:user].id
    assert_equal "test@example.com", result[:user].email
  end

  test "raises error when no authentication succeeds" do
    ActionMCP.configure do |config|
      config.authentication_methods = [ "jwt" ]
    end

    gateway = ActionMCP::Gateway.new
    request = MockRequest.new
    gateway.instance_variable_set(:@request, request)

    assert_raises ActionMCP::UnauthorizedError do
      gateway.send(:authenticate!)
    end
  end

  test "default_user_identity creates proper structure" do
    ActionMCP.configure do |config|
      config.authentication_methods = [ "none" ]
    end

    gateway = ActionMCP::Gateway.new

    def gateway.find_or_create_default_user
      User.new(id: 1, email: "test@example.com")
    end

    result = gateway.send(:default_user_identity)
    assert_equal 1, result[:user].id
    assert_equal "test@example.com", result[:user].email
  end

  private

  class MockRequest
    def headers
      {}
    end

    def env
      {}
    end
  end
end

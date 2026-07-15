# frozen_string_literal: true

module GatewayTestHelper
  TestUser = Data.define(:id, :email, :name)
  # Creates a test Gateway identifier for testing authentication scenarios
  class TestGatewayIdentifier < ActionMCP::GatewayIdentifier
    identifier :user
    authenticates :test

    def resolve
      user_id = @request.env["test.user_id"]
      raise Unauthorized, "No test user set" unless user_id

      TestUser.new(
        id: user_id,
        email: "test-#{user_id}@example.com",
        name: "Test User #{user_id}"
      )
    end
  end

  # Helper methods for setting up authentication in tests
  def authenticate_as(user_or_id)
    user_id = user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
    @request.env["test.user_id"] = user_id
  end

  def unauthenticated_request
    @request.env.delete("test.user_id")
  end

  def with_test_authentication
    config = ActionMCP.configuration
    had_gateway_override = config.instance_variable_defined?(:@gateway_class)
    original_gateway_override = config.instance_variable_get(:@gateway_class)
    original_auth_methods = ActionMCP.configuration.authentication_methods.dup

    # Create a temporary gateway class that uses our test identifier
    test_gateway_class = Class.new(ActionMCP::Gateway) do
      identified_by TestGatewayIdentifier
    end

    ActionMCP.configuration.gateway_class = test_gateway_class
    ActionMCP.configuration.authentication_methods = [ "test" ]

    yield
  ensure
    restore_gateway_override(config, had_gateway_override, original_gateway_override)
    ActionMCP.configuration.authentication_methods = original_auth_methods
  end

  def with_no_authentication
    config = ActionMCP.configuration
    had_gateway_override = config.instance_variable_defined?(:@gateway_class)
    original_gateway_override = config.instance_variable_get(:@gateway_class)
    original_auth_methods = ActionMCP.configuration.authentication_methods.dup

    ActionMCP.configuration.gateway_class = nil
    ActionMCP.configuration.authentication_methods = []

    yield
  ensure
    restore_gateway_override(config, had_gateway_override, original_gateway_override)
    ActionMCP.configuration.authentication_methods = original_auth_methods
  end

  # Creates a test user mock for testing
  def create_test_user(id: "test_user", email: nil, name: nil)
    TestUser.new(
      id: id,
      email: email || "#{id}@example.com",
      name: name || "Test User #{id}"
    )
  end

  # Sets up a Gateway test double for the current test
  def setup_test_gateway
    ActionMCP.configuration.gateway_class = TestGatewayIdentifier
  end

  # Creates mock session data for testing
  def create_test_session(user_id: "test_user")
    {
      "user_id" => user_id,
      "authenticated_at" => Time.current
    }
  end

  private

  def restore_gateway_override(config, had_override, original_override)
    if had_override
      config.gateway_class = original_override
    elsif config.instance_variable_defined?(:@gateway_class)
      config.remove_instance_variable(:@gateway_class)
    end
  end
end

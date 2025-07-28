# frozen_string_literal: true

require "ostruct"

module GatewayTestHelper
  # Creates a test Gateway identifier for testing authentication scenarios
  class TestGatewayIdentifier < ActionMCP::GatewayIdentifier
    identifier :user
    authenticates :test

    def resolve
      user_id = @request.env["test.user_id"]
      raise Unauthorized, "No test user set" unless user_id

      OpenStruct.new(
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
    original_gateway_class = ActionMCP.configuration.gateway_class
    original_auth_methods = ActionMCP.configuration.authentication_methods.dup

    # Create a temporary gateway class that uses our test identifier
    test_gateway_class = Class.new(ActionMCP::Gateway) do
      identified_by TestGatewayIdentifier
    end

    ActionMCP.configuration.gateway_class = test_gateway_class
    ActionMCP.configuration.authentication_methods = [ "test" ]

    yield
  ensure
    ActionMCP.configuration.gateway_class = original_gateway_class
    ActionMCP.configuration.authentication_methods = original_auth_methods
  end

  def with_no_authentication
    original_gateway_class = ActionMCP.configuration.gateway_class
    original_auth_methods = ActionMCP.configuration.authentication_methods.dup

    ActionMCP.configuration.gateway_class = nil
    ActionMCP.configuration.authentication_methods = []

    yield
  ensure
    ActionMCP.configuration.gateway_class = original_gateway_class
    ActionMCP.configuration.authentication_methods = original_auth_methods
  end

  # Creates a test user mock for testing
  def create_test_user(id: "test_user", email: nil, name: nil)
    OpenStruct.new(
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
end

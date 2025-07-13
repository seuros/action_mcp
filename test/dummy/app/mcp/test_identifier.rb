# frozen_string_literal: true

# Test identifier for ActionMCP testing
class TestIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :test

  def resolve
    "test_user"
  end
end

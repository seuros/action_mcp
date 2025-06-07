# frozen_string_literal: true

require "test_helper"

class ActionMCP::OAuth::ErrorTest < ActiveSupport::TestCase
  test "base OAuth error has oauth_error_code" do
    error = ActionMCP::OAuth::Error.new("Test error", "test_error")
    assert_equal "Test error", error.message
    assert_equal "test_error", error.oauth_error_code
  end

  test "base OAuth error defaults to invalid_request" do
    error = ActionMCP::OAuth::Error.new("Test error")
    assert_equal "invalid_request", error.oauth_error_code
  end

  test "InvalidTokenError has correct error code" do
    error = ActionMCP::OAuth::InvalidTokenError.new
    assert_equal "invalid_token", error.oauth_error_code
    assert_equal "Invalid token", error.message
  end

  test "InsufficientScopeError has required_scope attribute" do
    error = ActionMCP::OAuth::InsufficientScopeError.new("Need more scope", "mcp:tools")
    assert_equal "insufficient_scope", error.oauth_error_code
    assert_equal "Need more scope", error.message
    assert_equal "mcp:tools", error.required_scope
  end

  test "all error classes have correct error codes" do
    error_classes = {
      ActionMCP::OAuth::InvalidRequestError => "invalid_request",
      ActionMCP::OAuth::InvalidClientError => "invalid_client",
      ActionMCP::OAuth::InvalidGrantError => "invalid_grant",
      ActionMCP::OAuth::UnauthorizedClientError => "unauthorized_client",
      ActionMCP::OAuth::UnsupportedGrantTypeError => "unsupported_grant_type",
      ActionMCP::OAuth::InvalidScopeError => "invalid_scope",
      ActionMCP::OAuth::ServerError => "server_error",
      ActionMCP::OAuth::TemporarilyUnavailableError => "temporarily_unavailable"
    }

    error_classes.each do |error_class, expected_code|
      error = error_class.new
      assert_equal expected_code, error.oauth_error_code, "#{error_class} should have error code #{expected_code}"
    end
  end
end

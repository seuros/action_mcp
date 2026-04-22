# frozen_string_literal: true

require "test_helper"

# Tests MCP spec requirement: servers MUST validate the Origin header on all
# incoming connections to prevent DNS rebinding attacks.
# Spec: Streamable HTTP transport, Security section (2025-11-25).
class OriginValidationTest < ActionDispatch::IntegrationTest
  setup do
    @base_url = "http://localhost:62770"
    @original_allowed_origins = ActionMCP.configuration.allowed_origins
  end

  teardown do
    ActionMCP.configuration.allowed_origins = @original_allowed_origins
  end

  # Non-browser clients (Claude Desktop, curl) never send Origin — must be allowed.
  test "allows request with no Origin header" do
    get @base_url
    assert_response :method_not_allowed
  end

  # Same-host browser origin is always allowed.
  test "allows same-host Origin" do
    get @base_url, headers: { "Origin" => "http://localhost" }
    assert_response :method_not_allowed
  end

  test "allows same-host Origin regardless of scheme or port" do
    get @base_url, headers: { "Origin" => "https://localhost:443" }
    assert_response :method_not_allowed
  end

  # DNS rebinding: evil.com rebinds to 127.0.0.1, browser sends Origin: http://evil.com
  test "rejects foreign Origin" do
    get @base_url, headers: { "Origin" => "http://evil.com" }
    assert_response :forbidden
  end

  test "rejects null Origin" do
    get @base_url, headers: { "Origin" => "null" }
    assert_response :forbidden
  end

  # 403 body must be JSON-RPC with no id per MCP spec.
  test "forbidden response is JSON-RPC with no id" do
    post @base_url,
         params: { jsonrpc: "2.0", id: "req-1", method: "initialize", params: {} }.to_json,
         headers: {
           "Content-Type" => "application/json",
           "Accept" => "application/json",
           "Origin" => "http://evil.com"
         }

    assert_response :forbidden
    body = response.parsed_body
    assert_equal "2.0", body["jsonrpc"]
    assert_nil body["id"]
    assert body.dig("error", "code")
  end

  # Explicit allowed_origins configuration.
  test "allows Origin on explicit allowed_origins list" do
    ActionMCP.configuration.allowed_origins = [ "trusted.example.com" ]

    get @base_url, headers: { "Origin" => "https://trusted.example.com" }
    assert_response :method_not_allowed
  end

  test "rejects Origin not on explicit allowed_origins list" do
    ActionMCP.configuration.allowed_origins = [ "trusted.example.com" ]

    get @base_url, headers: { "Origin" => "https://other.example.com" }
    assert_response :forbidden
  end

  test "allowed_origins accepts Regexp patterns" do
    ActionMCP.configuration.allowed_origins = [ /\Atrusted\.example\.com\z/i ]

    get @base_url, headers: { "Origin" => "https://trusted.example.com" }
    assert_response :method_not_allowed

    get @base_url, headers: { "Origin" => "https://evil.example.com" }
    assert_response :forbidden
  end

  # IPv6 normalization: URI.parse returns "[::1]" — patterns written as "::1" must match.
  test "allowed_origins entry without brackets matches bracketed IPv6 Origin" do
    ActionMCP.configuration.allowed_origins = [ "::1" ]

    get @base_url, headers: { "Origin" => "http://[::1]" }
    assert_response :method_not_allowed
  end
end

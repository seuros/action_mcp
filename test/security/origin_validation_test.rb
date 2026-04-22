# frozen_string_literal: true

require "test_helper"

class OriginValidationTest < ActionDispatch::IntegrationTest
  setup do
    @base_url = "http://localhost:62770"
    @original_allowed_origins = ActionMCP.configuration.allowed_origins
  end

  teardown do
    ActionMCP.configuration.allowed_origins = @original_allowed_origins
  end

  test "allows request with no Origin header" do
    get @base_url
    assert_response :method_not_allowed
  end

  test "allows same-host Origin" do
    get @base_url, headers: { "Origin" => "http://localhost" }
    assert_response :method_not_allowed
  end

  test "allows same-host Origin regardless of scheme or port" do
    get @base_url, headers: { "Origin" => "https://localhost:443" }
    assert_response :method_not_allowed
  end

  test "rejects foreign Origin" do
    get @base_url, headers: { "Origin" => "http://evil.com" }
    assert_response :forbidden
  end

  test "rejects null Origin" do
    get @base_url, headers: { "Origin" => "null" }
    assert_response :forbidden
  end

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

  test "allowed_origins entry without brackets matches bracketed IPv6 Origin" do
    ActionMCP.configuration.allowed_origins = [ "::1" ]

    get @base_url, headers: { "Origin" => "http://[::1]" }
    assert_response :method_not_allowed
  end
end

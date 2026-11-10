# frozen_string_literal: true

require "test_helper"

class MCPNoneAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @session_id = initialize_mcp_session(complete: false, protocol_version: "2025-11-25", client_name: "test-client")

    mcp_notify("notifications/initialized", session_id: @session_id, protocol_version: "2025-11-25")
    assert_response :accepted
  end

  {
    "tools/list works without authentication in none mode" => [ "none" ],
    # Without credentials, api_key falls through to none
    "fallback authentication allows requests without authentication" => %w[api_key none]
  }.each do |name, auth_methods|
    test name do
      with_authentication_config(auth_methods) do
        mcp_post("tools/list", id: 2, session_id: @session_id)

        assert_response :success
        body = response.parsed_body
        assert body["result"]["tools"].is_a?(Array)
      end
    end
  end

  test "user_info tool shows default dev user in none mode" do
    with_authentication_config([ "none" ]) do
      mcp_post("tools/call", {
        name: "user_info",
        arguments: { include_sensitive: false, include_auth_details: false }
      }, id: 3, session_id: @session_id)

      assert_response :success
      body = response.parsed_body

      # Check the tool response
      assert body["result"], "Response should have result: #{body.inspect}"
      content = body["result"]["content"]
      assert content.is_a?(Array), "Content should be an array: #{content.inspect}"
      # Should have the default dev user
      assert(content.any? { |c| c["text"]&.include?("dev@localhost") }, "Should contain dev user info")
    end
  end
end

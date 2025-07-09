require "test_helper"

module ActionMCP
  class OAuthAuthenticationTest < ActionDispatch::IntegrationTest
    setup do
      # Enable OAuth authentication for these tests
      @original_auth = ActionMCP.configuration.authentication_methods
      ActionMCP.configuration.authentication_methods = [ "oauth" ]
      @original_oauth_config = ActionMCP.configuration.oauth_config
      ActionMCP.configuration.oauth_config = {
        storage: "ActionMCP::OAuth::ActiveRecordStorage",
        enable_dynamic_registration: true
      }
      ActionMCP::OAuth::Provider.instance_variable_set(:@oauth_config, nil)

      # Initialize a session
      post "/",
        params: {
          jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: {
            protocolVersion: "2025-03-26",
            clientInfo: { name: "test-client", version: "1.0" },
            capabilities: {}
          }
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }

      assert_response :success
      @session_id = response.headers["Mcp-Session-Id"]
    end

    teardown do
      ActionMCP.configuration.authentication_methods = @original_auth
      ActionMCP.configuration.oauth_config = @original_oauth_config
    end

    test "unauthorized response includes WWW-Authenticate header with OAuth enabled" do
      # Make request without authentication
      post "/",
        params: {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/list"
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Mcp-Session-Id" => @session_id
        }

      assert_response :unauthorized
      assert_equal 'Bearer realm="MCP API"', response.headers["WWW-Authenticate"]

      body = JSON.parse(response.body)
      assert_equal "No valid authentication found", body["error"]["message"]
    end

    test "WWW-Authenticate header not included when OAuth is disabled" do
      # Disable OAuth
      ActionMCP.configuration.authentication_methods = [ "jwt" ]

      post "/",
        params: {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/list"
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Mcp-Session-Id" => @session_id
        }

      assert_response :unauthorized
      assert_nil response.headers["WWW-Authenticate"]
    end

    test "OAuth metadata endpoints are available" do
      # Test authorization server metadata
      get "/.well-known/oauth-authorization-server"
      assert_response :success

      metadata = JSON.parse(response.body)
      assert metadata["issuer"]
      assert metadata["authorization_endpoint"]
      assert metadata["token_endpoint"]
      assert metadata["registration_endpoint"]

      # Test protected resource metadata
      get "/.well-known/oauth-protected-resource"
      assert_response :success

      resource_metadata = JSON.parse(response.body)
      assert resource_metadata["resource"]
      assert resource_metadata["authorization_servers"]
    end

    test "dynamic client registration works" do
      post "/oauth/register",
        params: {
          client_name: "Test MCP Client",
          redirect_uris: [ "http://localhost:3000/callback" ],
          grant_types: [ "authorization_code" ],
          response_types: [ "code" ],
          token_endpoint_auth_method: "none"
        }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }


      assert_response :created

      registration = JSON.parse(response.body)
      assert registration["client_id"]
      assert_equal "Test MCP Client", registration["client_name"]
      assert_equal [ "http://localhost:3000/callback" ], registration["redirect_uris"]
      assert registration["client_id_issued_at"]

      # Verify client was saved to database
      client = ActionMCP::OAuthClient.find_by(client_id: registration["client_id"])
      assert client
      assert_equal "Test MCP Client", client.client_name
    end
  end
end

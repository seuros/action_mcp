# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module ActionMCP
  module Client
    class OauthClientProviderTest < ActiveSupport::TestCase
      def setup
        @server_url = "https://oauth.example.com"
        @redirect_url = "http://localhost:3000/callback"
        @client_metadata = {
          client_name: "Test Client",
          client_id: "test_client_123"
        }

        @provider = OauthClientProvider.new(
          authorization_server_url: @server_url,
          redirect_url: @redirect_url,
          client_metadata: @client_metadata,
          logger: ActionMCP.logger
        )

        # Mock server metadata
        @mock_metadata = {
          authorization_endpoint: "#{@server_url}/oauth/authorize",
          token_endpoint: "#{@server_url}/oauth/token",
          issuer: @server_url,
          scopes_supported: [ "read", "write" ],
          response_types_supported: [ "code" ],
          grant_types_supported: [ "authorization_code", "refresh_token" ],
          code_challenge_methods_supported: [ "S256" ]
        }
      end

      test "initializes with correct configuration" do
        assert_equal @server_url, @provider.authorization_server_url.to_s
        assert_equal @redirect_url, @provider.redirect_url.to_s
        assert_equal "Test Client", @provider.client_metadata[:client_name]
      end

      test "is not authenticated initially" do
        assert_not @provider.authenticated?
        assert_nil @provider.access_token
      end

      test "generates authorization URL with PKCE" do
        mock_server_metadata_request

        authorization_url = @provider.start_authorization_flow(scope: "read write")

        uri = URI(authorization_url)
        params = URI.decode_www_form(uri.query).to_h

        assert_equal "#{@server_url}/oauth/authorize", "#{uri.scheme}://#{uri.host}#{uri.path}"
        assert_equal "code", params["response_type"]
        assert_equal @client_metadata[:client_id], params["client_id"]
        assert_equal @redirect_url, params["redirect_uri"]
        assert_equal "read write", params["scope"]
        assert_equal "S256", params["code_challenge_method"]
        assert_not_nil params["code_challenge"]
      end

      test "completes authorization flow successfully" do
        mock_server_metadata_request
        mock_token_request_success

        # Start flow to generate code verifier
        @provider.start_authorization_flow

        # Complete with authorization code
        tokens = @provider.complete_authorization_flow("auth_code_123")

        assert_equal "access_token_123", tokens[:access_token]
        assert_equal "refresh_token_123", tokens[:refresh_token]
        assert_equal "Bearer", tokens[:token_type]
        assert_not_nil tokens[:expires_at]
        assert @provider.authenticated?
      end

      test "handles token request errors" do
        mock_server_metadata_request
        mock_token_request_error

        @provider.start_authorization_flow

        error = assert_raises(OauthClientProvider::AuthenticationError) do
          @provider.complete_authorization_flow("invalid_code")
        end

        assert_includes error.message, "The authorization code is invalid"
      end

      test "refreshes tokens successfully" do
        mock_server_metadata_request
        mock_refresh_token_success

        # Set up existing tokens
        tokens = {
          access_token: "old_token",
          refresh_token: "refresh_token_123",
          expires_at: Time.now.to_i - 100 # Expired
        }
        @provider.send(:save_tokens, tokens)

        new_tokens = @provider.refresh_tokens!

        assert_equal "new_access_token", new_tokens[:access_token]
        assert_equal "new_refresh_token", new_tokens[:refresh_token]
        assert @provider.authenticated?
      end

      test "detects expired tokens and refreshes automatically" do
        mock_server_metadata_request
        mock_refresh_token_success

        # Set up expired tokens
        expired_tokens = {
          access_token: "expired_token",
          refresh_token: "refresh_token_123",
          expires_at: Time.now.to_i - 100 # Expired
        }
        @provider.send(:save_tokens, expired_tokens)

        # Should trigger automatic refresh
        access_token = @provider.access_token

        assert_equal "new_access_token", access_token
      end

      test "returns correct authorization headers" do
        tokens = {
          access_token: "test_token_123",
          token_type: "Bearer",
          expires_at: Time.now.to_i + 3600
        }
        @provider.send(:save_tokens, tokens)

        headers = @provider.authorization_headers
        assert_equal "Bearer test_token_123", headers["Authorization"]
      end

      test "clears tokens on logout" do
        tokens = {
          access_token: "test_token",
          refresh_token: "refresh_token"
        }
        @provider.send(:save_tokens, tokens)

        assert @provider.authenticated?

        @provider.clear_tokens!

        assert_not @provider.authenticated?
        assert_nil @provider.access_token
      end

      test "clear_tokens! also clears code verifier" do
        mock_server_metadata_request

        # Start flow to generate code verifier
        @provider.start_authorization_flow
        storage = @provider.instance_variable_get(:@storage)

        # Verify code verifier exists
        assert_not_nil storage.load_code_verifier

        # Clear tokens
        @provider.clear_tokens!

        # Verify code verifier is also cleared
        assert_nil storage.load_code_verifier
      end

      test "refresh_tokens! raises error when no refresh token available" do
        mock_server_metadata_request

        # Set up tokens without refresh token
        tokens = {
          access_token: "test_token",
          expires_at: Time.now.to_i - 100 # Expired
        }
        @provider.send(:save_tokens, tokens)

        error = assert_raises(OauthClientProvider::TokenExpiredError) do
          @provider.refresh_tokens!
        end

        assert_includes error.message, "No refresh token available"
      end

      test "handles missing code verifier error" do
        mock_server_metadata_request

        error = assert_raises(OauthClientProvider::AuthenticationError) do
          @provider.complete_authorization_flow("auth_code_123")
        end

        assert_includes error.message, "No code verifier found"
      end

      test "handles server metadata fetch errors" do
        stub_request(:get, "#{@server_url}/.well-known/oauth-authorization-server")
          .to_return(status: 404, body: "Not Found")

        error = assert_raises(OauthClientProvider::AuthenticationError) do
          @provider.start_authorization_flow
        end

        assert_includes error.message, "Failed to fetch server metadata"
      end

      test "memory storage works correctly" do
        storage = OauthClientProvider::MemoryStorage.new

        # Test tokens
        tokens = { access_token: "test" }
        storage.save_tokens(tokens)
        assert_equal tokens, storage.load_tokens

        storage.clear_tokens
        assert_nil storage.load_tokens

        # Test code verifier
        verifier = "test_verifier"
        storage.save_code_verifier(verifier)
        assert_equal verifier, storage.load_code_verifier

        storage.clear_code_verifier
        assert_nil storage.load_code_verifier

        # Test client info
        client_info = { client_id: "test" }
        storage.save_client_information(client_info)
        assert_equal client_info, storage.load_client_information
      end

      private

      def mock_server_metadata_request
        stub_request(:get, "#{@server_url}/.well-known/oauth-authorization-server")
          .to_return(
            status: 200,
            body: @mock_metadata.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      def mock_token_request_success
        stub_request(:post, @mock_metadata[:token_endpoint])
          .to_return(
            status: 200,
            body: {
              access_token: "access_token_123",
              refresh_token: "refresh_token_123",
              token_type: "Bearer",
              expires_in: 3600
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      def mock_token_request_error
        stub_request(:post, @mock_metadata[:token_endpoint])
          .to_return(
            status: 400,
            body: {
              error: "invalid_grant",
              error_description: "The authorization code is invalid"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      def mock_refresh_token_success
        stub_request(:post, @mock_metadata[:token_endpoint])
          .to_return(
            status: 200,
            body: {
              access_token: "new_access_token",
              refresh_token: "new_refresh_token",
              token_type: "Bearer",
              expires_in: 3600
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end
    end
  end
end

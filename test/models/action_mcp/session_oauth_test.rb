# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class SessionOAuthTest < ActiveSupport::TestCase
    fixtures :action_mcp_sessions

    def setup
      @session = action_mcp_sessions(:test_session)
    end

    test "can store OAuth token and user context" do
      expires_at = 1.hour.from_now
      user_context = {
        user_id: "user123",
        client_id: "client456",
        scopes: [ "mcp:tools", "mcp:resources" ]
      }

      @session.store_oauth_token(
        access_token: "access_token_123",
        refresh_token: "refresh_token_456",
        expires_at: expires_at,
        user_context: user_context
      )

      @session.reload
      assert_equal "access_token_123", @session.oauth_access_token
      assert_equal "refresh_token_456", @session.oauth_refresh_token
      assert_equal expires_at.to_i, @session.oauth_token_expires_at.to_i
      assert_equal user_context.stringify_keys, @session.oauth_user_context
      assert_equal "oauth", @session.authentication_method
    end

    test "oauth_token_info returns complete token information" do
      expires_at = 1.hour.from_now
      user_context = { user_id: "user123", scopes: [ "mcp:tools" ] }

      @session.store_oauth_token(
        access_token: "token123",
        refresh_token: "refresh123",
        expires_at: expires_at,
        user_context: user_context
      )

      token_info = @session.oauth_token_info
      assert_equal "token123", token_info[:access_token]
      assert_equal "refresh123", token_info[:refresh_token]
      assert_equal expires_at.to_i, token_info[:expires_at].to_i
      assert_equal user_context.stringify_keys, token_info[:user_context]
      assert_equal "oauth", token_info[:authentication_method]
    end

    test "oauth_token_info returns nil when no token stored" do
      assert_nil @session.oauth_token_info
    end

    test "oauth_token_valid? checks token existence and expiration" do
      # No token stored
      assert_not @session.oauth_token_valid?

      # Valid unexpired token
      @session.store_oauth_token(
        access_token: "token123",
        expires_at: 1.hour.from_now,
        user_context: {}
      )
      assert @session.oauth_token_valid?

      # Expired token
      @session.update!(oauth_token_expires_at: 1.hour.ago)
      assert_not @session.oauth_token_valid?

      # Token without expiration (valid)
      @session.update!(oauth_token_expires_at: nil)
      assert @session.oauth_token_valid?
    end

    test "can clear OAuth token data" do
      @session.store_oauth_token(
        access_token: "token123",
        refresh_token: "refresh123",
        expires_at: 1.hour.from_now,
        user_context: { user_id: "user123" }
      )

      @session.clear_oauth_token!
      @session.reload

      assert_nil @session.oauth_access_token
      assert_nil @session.oauth_refresh_token
      assert_nil @session.oauth_token_expires_at
      assert_nil @session.oauth_user_context
      assert_equal "none", @session.authentication_method
    end

    test "can update OAuth token for refresh flow" do
      @session.store_oauth_token(
        access_token: "old_token",
        refresh_token: "old_refresh",
        expires_at: 1.hour.from_now,
        user_context: { user_id: "user123" }
      )

      new_expires_at = 2.hours.from_now
      @session.update_oauth_token(
        access_token: "new_token",
        refresh_token: "new_refresh",
        expires_at: new_expires_at
      )

      @session.reload
      assert_equal "new_token", @session.oauth_access_token
      assert_equal "new_refresh", @session.oauth_refresh_token
      assert_equal new_expires_at.to_i, @session.oauth_token_expires_at.to_i
      # User context should be preserved
      assert_equal({ "user_id" => "user123" }, @session.oauth_user_context)
    end

    test "oauth_user returns OpenStruct with user data" do
      @session.store_oauth_token(
        access_token: "token123",
        expires_at: 1.hour.from_now,
        user_context: {
          user_id: "user123",
          email: "user@example.com",
          name: "Test User"
        }
      )

      user = @session.oauth_user
      assert_instance_of OpenStruct, user
      assert_equal "user123", user.user_id
      assert_equal "user@example.com", user.email
      assert_equal "Test User", user.name
    end

    test "oauth_user returns nil when no user context" do
      assert_nil @session.oauth_user

      @session.store_oauth_token(
        access_token: "token123",
        expires_at: 1.hour.from_now,
        user_context: nil
      )
      assert_nil @session.oauth_user
    end

    test "oauth_authenticated? checks method and validity" do
      # Not authenticated initially
      assert_not @session.oauth_authenticated?

      # Valid OAuth token
      @session.store_oauth_token(
        access_token: "token123",
        expires_at: 1.hour.from_now,
        user_context: {}
      )
      assert @session.oauth_authenticated?

      # Expired token
      @session.update!(oauth_token_expires_at: 1.hour.ago)
      assert_not @session.oauth_authenticated?

      # Different auth method
      @session.update!(authentication_method: "jwt")
      assert_not @session.oauth_authenticated?
    end

    test "find_by_oauth_token finds session by access token" do
      @session.store_oauth_token(
        access_token: "unique_token_123",
        expires_at: 1.hour.from_now,
        user_context: {}
      )

      found_session = ActionMCP::Session.find_by_oauth_token("unique_token_123")
      assert_equal @session.id, found_session.id

      assert_nil ActionMCP::Session.find_by_oauth_token("nonexistent_token")
    end

    test "with_expired_oauth_tokens scope finds expired tokens" do
      # Create sessions with different token states
      expired_session = ActionMCP::Session.create!(id: "expired")
      expired_session.store_oauth_token(
        access_token: "expired_token",
        expires_at: 1.hour.ago,
        user_context: {}
      )

      valid_session = ActionMCP::Session.create!(id: "valid")
      valid_session.store_oauth_token(
        access_token: "valid_token",
        expires_at: 1.hour.from_now,
        user_context: {}
      )

      no_token_session = ActionMCP::Session.create!(id: "no_token")

      expired_sessions = ActionMCP::Session.with_expired_oauth_tokens
      assert_includes expired_sessions, expired_session
      assert_not_includes expired_sessions, valid_session
      assert_not_includes expired_sessions, no_token_session
    end

    test "cleanup_expired_oauth_tokens removes expired token data" do
      # Create expired session
      expired_session = ActionMCP::Session.create!(id: "expired")
      expired_session.store_oauth_token(
        access_token: "expired_token",
        expires_at: 1.hour.ago,
        user_context: { user_id: "user123" }
      )

      # Create valid session
      valid_session = ActionMCP::Session.create!(id: "valid")
      valid_session.store_oauth_token(
        access_token: "valid_token",
        expires_at: 1.hour.from_now,
        user_context: { user_id: "user456" }
      )

      ActionMCP::Session.cleanup_expired_oauth_tokens

      expired_session.reload
      valid_session.reload

      # Expired session should have OAuth data cleared
      assert_nil expired_session.oauth_access_token
      assert_nil expired_session.oauth_user_context
      assert_equal "none", expired_session.authentication_method

      # Valid session should be untouched
      assert_equal "valid_token", valid_session.oauth_access_token
      assert_equal({ "user_id" => "user456" }, valid_session.oauth_user_context)
      assert_equal "oauth", valid_session.authentication_method
    end

    test "database agnostic JSON storage works" do
      user_context = {
        user_id: "user123",
        permissions: %w[read write],
        metadata: { role: "admin", department: "engineering" }
      }

      @session.store_oauth_token(
        access_token: "token123",
        expires_at: 1.hour.from_now,
        user_context: user_context
      )

      @session.reload
      stored_context = @session.oauth_user_context

      # Verify complex JSON structure is preserved
      assert_equal "user123", stored_context["user_id"]
      assert_equal %w[read write], stored_context["permissions"]
      assert_equal "admin", stored_context.dig("metadata", "role")
      assert_equal "engineering", stored_context.dig("metadata", "department")
    end
  end
end

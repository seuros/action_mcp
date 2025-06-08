# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_session_messages
#
#  id                   :bigint           not null, primary key
#  direction            :string           default("client"), not null
#  is_ping              :boolean          default(FALSE), not null
#  message_json         :json
#  message_type         :string           not null
#  request_acknowledged :boolean          default(FALSE), not null
#  request_cancelled    :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  jsonrpc_id           :string
#  session_id           :string           not null
#
# Indexes
#
#  index_action_mcp_session_messages_on_session_id  (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (session_id => action_mcp_sessions.id) ON DELETE => cascade ON UPDATE => cascade
#
require "test_helper"

module ActionMCP
  class Session
    class MessageTest < ActiveSupport::TestCase
      # Setup method to create a fresh session before each test
      setup do
        @session = ActionMCP::Session.create!
      end

      # Test that "ping" requests are identified correctly
      test "sets is_ping to true for ping requests" do
        ping_payload = { "id" => 123, "method" => "ping", "jsonrpc" => "2.0" }
        message = @session.messages.create!(direction: "client", data: ping_payload)

        assert_equal "request", message.message_type, "Message type should be 'request'"
        assert_equal "123", message.jsonrpc_id, "jsonrpc_id should match the payload"
        assert message.is_ping, "is_ping should be true for ping requests"
        refute message.request_acknowledged, "request_acknowledged should be false initially"
      end

      # Test that non-"ping" requests are not marked as ping
      test "does not set is_ping for non-ping requests" do
        non_ping_payload = { "id" => 456, "method" => "other_method", "jsonrpc" => "2.0" }
        message = @session.messages.create!(direction: "client", data: non_ping_payload)

        assert_equal "request", message.message_type, "Message type should be 'request'"
        assert_equal "456", message.jsonrpc_id, "jsonrpc_id should match the payload"
        refute message.is_ping, "is_ping should be false for non-ping requests"
        refute message.request_acknowledged, "request_acknowledged should be false"
      end

      # Test that a successful "pong" response acknowledges a "ping" request
      test "acknowledges ping on successful response" do
        ping_payload = { "id" => 789, "method" => "ping", "jsonrpc" => "2.0" }
        ping_message = @session.messages.create!(direction: "client", data: ping_payload)

        response_payload = { "id" => 789, "result" => "pong", "jsonrpc" => "2.0" }
        @session.messages.create!(direction: "server", data: response_payload)

        ping_message.reload
        assert ping_message.request_acknowledged, "request_acknowledged should be true after response"
      end

      # Test that an error response still acknowledges a "ping" request
      test "acknowledges ping on error response" do
        ping_payload = { "id" => 101, "method" => "ping", "jsonrpc" => "2.0" }
        ping_message = @session.messages.create!(direction: "client", data: ping_payload)

        error_response_payload = { "id" => 101, "error" => { "code" => -32_600, "message" => "Invalid Request" },
                                   "jsonrpc" => "2.0" }
        @session.messages.create!(direction: "server", data: error_response_payload)

        ping_message.reload
        assert ping_message.request_acknowledged, "request_acknowledged should be true after error response"
      end

      # Test that a response with a different jsonrpc_id does not acknowledge a "ping"
      test "does not acknowledge ping for non-matching jsonrpc_id" do
        ping_payload = { "id" => 202, "method" => "ping", "jsonrpc" => "2.0" }
        ping_message = @session.messages.create!(direction: "client", data: ping_payload)

        response_payload = { "id" => 203, "result" => "pong", "jsonrpc" => "2.0" }
        @session.messages.create!(direction: "server", data: response_payload)

        ping_message.reload
        refute ping_message.request_acknowledged, "request_acknowledged should remain false for non-matching id"
      end

      # Test handling of JSON payloads that are not JSON-RPC compliant
      test "handles JSON payloads that are not JSON-RPC" do
        non_jsonrpc_payload = { "key" => "value" }
        message = @session.messages.create(direction: "client", data: non_jsonrpc_payload)

        assert_not message.persisted?, "Message should not be persisted if not JSON-RPC compliant"
      end

      # Test handling of string-based jsonrpc_id
      test "handles string jsonrpc_id" do
        ping_payload = { "id" => "abc123", "method" => "ping", "jsonrpc" => "2.0" }
        ping_message = @session.messages.create!(direction: "client", data: ping_payload)

        response_payload = { "id" => "abc123", "result" => "pong", "jsonrpc" => "2.0" }
        @session.messages.create!(direction: "server", data: response_payload)

        ping_message.reload
        assert_equal "abc123", ping_message.jsonrpc_id, "jsonrpc_id should match the string id"
        assert ping_message.is_ping, "is_ping should be true"
        assert ping_message.request_acknowledged, "request_acknowledged should be true"
      end

      # Test handling of integer-based jsonrpc_id
      test "handles integer jsonrpc_id" do
        ping_payload = { "id" => 456, "method" => "ping", "jsonrpc" => "2.0" }
        ping_message = @session.messages.create!(direction: "client", data: ping_payload)

        response_payload = { "id" => 456, "result" => "pong", "jsonrpc" => "2.0" }
        @session.messages.create!(direction: "server", data: response_payload)

        ping_message.reload
        assert_equal "456", ping_message.jsonrpc_id, "jsonrpc_id should match the integer id as a string"
        assert ping_message.is_ping, "is_ping should be true"
        assert ping_message.request_acknowledged, "request_acknowledged should be true"
      end

      test "excludes both ping requests and their responses using without_pings scope" do
        # Create a ping request
        ping_payload = { "id" => 123, "method" => "ping", "jsonrpc" => "2.0" }
        ping_request = @session.messages.create!(direction: "client", data: ping_payload)
        assert ping_request.is_ping, "Ping request should have is_ping: true"

        # Create a response to the ping request
        response_payload = { "id" => 123, "result" => "pong", "jsonrpc" => "2.0" }
        ping_response = @session.messages.create!(direction: "server", data: response_payload)
        assert ping_response.is_ping, "Response to ping should have is_ping: true"

        # Create a non-ping request and response
        non_ping_payload = { "id" => 456, "method" => "other_method", "jsonrpc" => "2.0" }
        non_ping_request = @session.messages.create!(direction: "client", data: non_ping_payload)
        refute non_ping_request.is_ping, "Non-ping request should have is_ping: false"

        non_ping_response_payload = { "id" => 456, "result" => "success", "jsonrpc" => "2.0" }
        non_ping_response = @session.messages.create!(direction: "server", data: non_ping_response_payload)
        refute non_ping_response.is_ping, "Response to non-ping should have is_ping: false"

        # Use the without_pings scope
        messages_without_pings = @session.messages.without_pings

        # Verify that ping request and response are excluded
        assert_not_includes messages_without_pings, ping_request, "Ping request should be excluded"
        assert_not_includes messages_without_pings, ping_response, "Ping response should be excluded"

        # Verify that non-ping request and response are included
        assert_includes messages_without_pings, non_ping_request, "Non-ping request should be included"
        assert_includes messages_without_pings, non_ping_response, "Non-ping response should be included"
      end
    end
  end
end

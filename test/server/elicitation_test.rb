# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ElicitationTest < ActiveSupport::TestCase
      fixtures :action_mcp_sessions

      # --- Form mode ---

      test "send_elicitation_create sends form mode request" do
        transport = transport_for(:elicitation_form_session)
        schema = {
          type: "object",
          properties: { name: { type: "string" } },
          required: [ "name" ]
        }

        result = transport.send_elicitation_create(
          message: "What is your name?",
          requested_schema: schema
        )

        assert_equal "elicitation/create", result.method
        assert_equal "form", result.params[:mode]
        assert_equal "What is your name?", result.params[:message]
        assert_equal schema, result.params[:requestedSchema]
      end

      test "send_elicitation_create validates schema must be object type" do
        transport = transport_for(:elicitation_form_session)

        assert_raises(ArgumentError) do
          transport.send_elicitation_create(
            message: "test",
            requested_schema: { type: "string" }
          )
        end
      end

      test "send_elicitation_create validates schema must have properties" do
        transport = transport_for(:elicitation_form_session)

        assert_raises(ArgumentError) do
          transport.send_elicitation_create(
            message: "test",
            requested_schema: { type: "object" }
          )
        end
      end

      test "send_elicitation_create rejects nested object properties" do
        transport = transport_for(:elicitation_form_session)

        assert_raises(ArgumentError) do
          transport.send_elicitation_create(
            message: "test",
            requested_schema: {
              type: "object",
              properties: { nested: { type: "object", properties: {} } }
            }
          )
        end
      end

      test "send_elicitation_create accepts enum array property" do
        transport = transport_for(:elicitation_form_session)
        schema = {
          type: "object",
          properties: {
            colors: {
              type: "array",
              items: { type: "string", enum: %w[red green blue] }
            }
          }
        }

        result = transport.send_elicitation_create(message: "Pick colors", requested_schema: schema)
        assert_equal "form", result.params[:mode]
      end

      test "send_elicitation_create accepts anyOf enum array property" do
        transport = transport_for(:elicitation_form_session)
        schema = {
          type: "object",
          properties: {
            colors: {
              type: "array",
              items: {
                anyOf: [
                  { const: "#FF0000", title: "Red" },
                  { const: "#00FF00", title: "Green" }
                ]
              }
            }
          }
        }

        result = transport.send_elicitation_create(message: "Pick colors", requested_schema: schema)
        assert_equal "form", result.params[:mode]
      end

      # --- URL mode ---

      test "send_elicitation_create_url sends url mode request" do
        transport = transport_for(:elicitation_url_session)

        result = transport.send_elicitation_create_url(
          message: "Please provide your API key",
          url: "https://example.com/auth",
          elicitation_id: "test-123"
        )

        assert_equal "elicitation/create", result.method
        assert_equal "url", result.params[:mode]
        assert_equal "Please provide your API key", result.params[:message]
        assert_equal "https://example.com/auth", result.params[:url]
        assert_equal "test-123", result.params[:elicitationId]
      end

      test "send_elicitation_create_url generates elicitation_id when not provided" do
        transport = transport_for(:elicitation_url_session)

        result = transport.send_elicitation_create_url(
          message: "Auth required",
          url: "https://example.com/oauth"
        )

        assert_not_nil result.params[:elicitationId]
      end

      test "send_elicitation_create_url rejects empty url" do
        transport = transport_for(:elicitation_url_session)

        assert_raises(ArgumentError) do
          transport.send_elicitation_create_url(message: "test", url: "")
        end
      end

      test "send_elicitation_create_url rejects non-http url" do
        transport = transport_for(:elicitation_url_session)

        assert_raises(ArgumentError) do
          transport.send_elicitation_create_url(message: "test", url: "ftp://example.com/file")
        end
      end

      test "send_elicitation_create_url includes meta when provided" do
        transport = transport_for(:elicitation_url_session)

        result = transport.send_elicitation_create_url(
          message: "Auth",
          url: "https://example.com/auth",
          _meta: { "io.modelcontextprotocol/related-task": { taskId: "task-1" } }
        )

        assert_not_nil result.params[:_meta]
      end

      # --- Completion notification ---

      test "send_elicitation_complete_notification sends notification" do
        transport = transport_for(:elicitation_url_session)

        result = transport.send_elicitation_complete_notification("elicit-123")

        assert_equal "notifications/elicitation/complete", result.method
        assert_equal "elicit-123", result.params[:elicitationId]
      end

      # --- URLElicitationRequiredError ---

      test "send_url_elicitation_required_error sends -32042 error" do
        transport = transport_for(:elicitation_url_session)

        result = transport.send_url_elicitation_required_error(
          "req-1",
          message: "Authorization required",
          elicitations: [
            {
              mode: "url",
              elicitationId: "e-1",
              url: "https://example.com/connect",
              message: "Connect your account"
            }
          ]
        )

        error = result.error
        assert_equal(-32_042, error[:code])
        assert_equal "Authorization required", error[:message]
        assert_equal 1, error[:data][:elicitations].size
        assert_equal "url", error[:data][:elicitations][0][:mode]
      end

      test "send_url_elicitation_required_error rejects non-url mode elicitations" do
        transport = transport_for(:elicitation_url_session)

        assert_raises(ArgumentError) do
          transport.send_url_elicitation_required_error(
            "req-1",
            message: "Auth required",
            elicitations: [ { mode: "form", message: "bad" } ]
          )
        end
      end

      test "send_url_elicitation_required_error rejects missing fields" do
        transport = transport_for(:elicitation_url_session)

        assert_raises(ArgumentError) do
          transport.send_url_elicitation_required_error(
            "req-1",
            message: "Auth required",
            elicitations: [ { mode: "url", url: "https://x.com", message: "go" } ]
          )
        end
      end

      # --- Client capability gating ---

      test "send_elicitation_create raises when client has no elicitation support" do
        transport = transport_for(:no_elicitation_session)

        assert_raises(ActionMCP::Server::UnsupportedElicitationError) do
          transport.send_elicitation_create(
            message: "test",
            requested_schema: { type: "object", properties: { name: { type: "string" } } }
          )
        end
      end

      test "send_elicitation_create_url raises on protocol 2025-06-18" do
        transport = transport_for(:elicitation_form_session)

        assert_raises(ActionMCP::Server::UnsupportedElicitationError) do
          transport.send_elicitation_create_url(message: "test", url: "https://example.com/auth")
        end
      end

      test "send_elicitation_create_url raises when client has no url mode support" do
        # elicitation_form_session has elicitation: {} (form only) + protocol 2025-06-18
        # Use a 2025-11-25 session with form-only caps
        session = action_mcp_sessions(:task_master_session)
        session.update!(client_capabilities: { "elicitation" => { "form" => {} } })
        transport = ActionMCP::Server::TransportHandler.new(session, messaging_mode: :return)

        assert_raises(ActionMCP::Server::UnsupportedElicitationError) do
          transport.send_elicitation_create_url(message: "test", url: "https://example.com/auth")
        end
      end

      test "send_elicitation_create works with form-only client" do
        transport = transport_for(:elicitation_form_session)

        result = transport.send_elicitation_create(
          message: "Name?",
          requested_schema: { type: "object", properties: { name: { type: "string" } } }
        )

        assert_equal "form", result.params[:mode]
      end

      # --- Elicitation is a client capability ---

      test "server capabilities do not include elicitation" do
        caps = ActionMCP.configuration.capabilities
        assert_nil caps[:elicitation]
      end

      private

      def transport_for(fixture_name)
        session = action_mcp_sessions(fixture_name)
        ActionMCP::Server::TransportHandler.new(session, messaging_mode: :return)
      end
    end
  end
end

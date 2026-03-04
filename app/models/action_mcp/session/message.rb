# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_session_messages"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", pk = true, null = false },
#   { name = "created_at", type = "datetime", null = false },
#   { name = "direction", type = "string", null = false, default = "client" },
#   { name = "is_ping", type = "boolean", null = false },
#   { name = "jsonrpc_id", type = "string" },
#   { name = "message_json", type = "json" },
#   { name = "message_type", type = "string", null = false },
#   { name = "request_acknowledged", type = "boolean", null = false },
#   { name = "request_cancelled", type = "boolean", null = false },
#   { name = "session_id", type = "string", null = false },
#   { name = "updated_at", type = "datetime", null = false }
# ]
#
# indexes = [
#   { name = "index_action_mcp_session_messages_on_session_id", columns = ["session_id"] }
# ]
#
# foreign_keys = [
#   { column = "session_id", references_table = "action_mcp_sessions", references_column = "id", on_delete = "cascade", on_update = "cascade" }
# ]
#
# [callbacks]
# after_create = [{ method = "acknowledge_request", if = ["proc"] }]
#
# notes = ["message_json:NOT_NULL", "direction:LIMIT", "jsonrpc_id:LIMIT", "message_type:LIMIT", "session_id:LIMIT", "message_type:INDEX"]
# <rails-lens:schema:end>
module ActionMCP
  class Session
    #
    # Represents a message exchanged during an MCP session.
    # Its role is to store the content and metadata of each message,
    # including the direction (client or server), message type (request, response, notification),
    # and any associated JSON-RPC ID.
    class Message < ApplicationRecord
      include MCPMessageInspect
      belongs_to :session,
                 class_name: "ActionMCP::Session",
                 inverse_of: :messages,
                 counter_cache: true

      delegate :role,
               to: :session

      # Virtual attribute for data
      attr_reader :data

      # Set is_ping on responses if the original request was a ping
      after_create :acknowledge_request, if: -> { %w[response error].include?(message_type) }

      # Scope to exclude both "ping" requests and their responses
      scope :without_pings, -> { where(is_ping: false) }

      scope :requests, -> { where(message_type: "request") }
      scope :notifications, -> { where(message_type: "notification") }
      scope :responses, -> { where(message_type: "response") }

      validates :message_json, presence: true
      validates :message_type, presence: true

      # @param payload [String, Hash]
      def data=(payload)
        # Convert string payloads to JSON
        if payload.is_a?(String)
          begin
            @data = MultiJson.load(payload)
          rescue MultiJson::ParseError
            # Handle invalid JSON by creating an error object
            self.message_json = { "error" => "Invalid JSON", "raw" => payload }
            self.message_type = "invalid_json"
            return
          end
        else
          # If it's already a hash/array, use it directly
          @data = payload
        end

        self.message_json = @data
        process_json_content(@data)
      end

      def data
        message_json
      end

      # Helper methods
      def request?
        message_type == "request"
      end

      def notification?
        message_type == "notification"
      end

      def response?
        message_type == "response"
      end

      def rpc_method
        return false unless request?

        data["method"]
      end

      private

      def process_json_content(content)
        if content.is_a?(JSON_RPC::Notification) || content.is_a?(JSON_RPC::Request) || content.is_a?(JSON_RPC::Response)
          content = content.to_h.with_indifferent_access
        end
        if content.is_a?(Hash)
          content = content.with_indifferent_access
          if content["jsonrpc"] == "2.0"
            if content.key?("id") && content.key?("method")
              self.message_type = "request"
              self.jsonrpc_id = content["id"].to_s
              # Set is_ping to true if the method is "ping"
              self.is_ping = true if content["method"] == "ping"
            elsif content.key?("method") && !content.key?("id")
              self.message_type = "notification"
            elsif content.key?("id") && content.key?("result")
              self.message_type = "response"
              self.jsonrpc_id = content["id"].to_s
            elsif content.key?("id") && content.key?("error")
              self.message_type = "error"
              self.jsonrpc_id = content["id"].to_s
            else
              self.message_type = "invalid_jsonrpc"
            end
          end
        else
          self.message_type = "non_jsonrpc_json"
        end
      end

      def acknowledge_request
        return unless jsonrpc_id.present?

        request_message = session.messages.find_by(
          jsonrpc_id: jsonrpc_id,
          message_type: "request"
        )

        return unless request_message

        # Set is_ping based on the request
        self.is_ping = request_message.is_ping

        # Mark the request as acknowledged for all responses
        request_message.update(request_acknowledged: true)

        save! if changed?
      end
    end
  end
end

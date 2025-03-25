# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_session_messages
#
#  id                                     :bigint           not null, primary key
#  direction(The message recipient)       :string           default("client"), not null
#  is_ping(Whether the message is a ping) :boolean          default(FALSE), not null
#  message_json                           :jsonb
#  message_type(The type of the message)  :string           not null
#  request_acknowledged                   :boolean          default(FALSE), not null
#  request_cancelled                      :boolean          default(FALSE), not null
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  jsonrpc_id                             :string
#  session_id                             :string           not null
#
# Indexes
#
#  index_action_mcp_session_messages_on_session_id  (session_id)
#
# Foreign Keys
#
#  fk_action_mcp_session_messages_session_id  (session_id => action_mcp_sessions.id) ON DELETE => cascade ON UPDATE => cascade
#
module ActionMCP
  class Session
    #
    # Represents a message exchanged during an MCP session.
    # Its role is to store the content and metadata of each message,
    # including the direction (client or server), message type (request, response, notification),
    # and any associated JSON-RPC ID.
    class Message < ApplicationRecord
      belongs_to :session,
                 class_name: "ActionMCP::Session",
                 inverse_of: :messages,
                 counter_cache: true

      delegate :adapter,
               :role,
               :session_key,
               to: :session

      # Virtual attribute for data
      attr_reader :data

      after_create_commit :broadcast_message, if: :outgoing_message?
      # Set is_ping on responses if the original request was a ping
      after_create :acknowledge_request, if: -> { %w[response error].include?(message_type) }

      # Scope to exclude both "ping" requests and their responses
      scope :without_pings, -> { where(is_ping: false) }

      scope :requests, -> { where(message_type: "request") }
      scope :notifications, -> { where(message_type: "notification") }
      scope :responses, -> { where(message_type: "response") }

      # @param payload [String, Hash]
      def data=(payload)
        @data = payload

        # Convert string payloads to JSON
        if payload.is_a?(String)
          begin
            parsed_json = MultiJson.load(payload)
            self.message_json = parsed_json
          rescue MultiJson::ParseError
            # Handle invalid JSON by creating an error object
            self.message_json = { "error" => "Invalid JSON", "raw" => payload }
            self.message_type = "invalid_json"
            return
          end
        else
          # Handle direct hash assignment
          self.message_json = payload
        end
        process_json_content(payload)
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

      def outgoing_message?
        direction != role
      end

      def broadcast_message
        return unless adapter.present?

        adapter.broadcast(session_key, data.to_json)
      end

      def process_json_content(content)
        if content.is_a?(Hash) && content["jsonrpc"] == "2.0"
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

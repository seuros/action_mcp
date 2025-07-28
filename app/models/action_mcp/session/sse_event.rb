# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_sse_events"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", primary_key = true, nullable = false },
#   { name = "session_id", type = "string", nullable = false },
#   { name = "event_id", type = "integer", nullable = false },
#   { name = "data", type = "text", nullable = false },
#   { name = "created_at", type = "datetime", nullable = false },
#   { name = "updated_at", type = "datetime", nullable = false }
# ]
#
# indexes = [
#   { name = "index_action_mcp_sse_events_on_created_at", columns = ["created_at"] },
#   { name = "index_action_mcp_sse_events_on_session_id_and_event_id", columns = ["session_id", "event_id"], unique = true },
#   { name = "index_action_mcp_sse_events_on_session_id", columns = ["session_id"] }
# ]
#
# foreign_keys = [
#   { column = "session_id", references_table = "action_mcp_sessions", references_column = "id" }
# ]
#
# == Notes
# - Association 'session' should specify inverse_of
# - String column 'session_id' has no length limit - consider adding one
# <rails-lens:schema:end>
module ActionMCP
  class Session
    # Represents a Server-Sent Event (SSE) in an MCP session
    # These events are stored for potential resumption when a client reconnects
    class SSEEvent < ApplicationRecord
      self.table_name = "action_mcp_sse_events"

      belongs_to :session, class_name: "ActionMCP::Session"

      # Validations
      validates :event_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :data, presence: true

      # Scopes
      scope :recent, -> { order(event_id: :desc) }
      scope :after_id, ->(id) { where("event_id > ?", id) }
      scope :before, ->(time) { where("created_at < ?", time) }

      # Serializes the data as JSON if it's not already a string
      def data_for_stream
        return data if data.is_a?(String)

        data.is_a?(Hash) ? data.to_json : data.to_s
      end

      # Generates the SSE formatted event string
      # @return [String] The formatted SSE event
      def to_sse
        "id: #{event_id}\ndata: #{data_for_stream}\n\n"
      end
    end
  end
end

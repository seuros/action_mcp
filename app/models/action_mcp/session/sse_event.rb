# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_sse_events
#
#  id         :integer          not null, primary key
#  data       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null
#  session_id :string           not null
#
# Indexes
#
#  index_action_mcp_sse_events_on_created_at               (created_at)
#  index_action_mcp_sse_events_on_session_id               (session_id)
#  index_action_mcp_sse_events_on_session_id_and_event_id  (session_id,event_id) UNIQUE
#
# Foreign Keys
#
#  session_id  (session_id => action_mcp_sessions.id)
#
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

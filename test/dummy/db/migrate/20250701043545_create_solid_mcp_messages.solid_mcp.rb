# frozen_string_literal: true

# This migration comes from solid_mcp (originally 20250624000001)
class CreateSolidMCPMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :solid_mcp_messages do |t|
      # Session this message belongs to
      t.string :session_id, null: false, limit: 36

      # Type of event (e.g., 'message', 'ping', 'connection_closed')
      t.string :event_type, null: false, limit: 50

      # The actual data payload
      t.text :data

      # Timestamp when message was created
      t.datetime :created_at, null: false

      # Timestamp when message was delivered
      t.datetime :delivered_at

      # Composite index for efficient polling
      t.index [ :session_id, :id ], name: "idx_solid_mcp_messages_on_session_and_id"

      # Index for cleanup
      t.index [ :delivered_at, :created_at ], name: "idx_solid_mcp_messages_on_delivered_and_created"
    end
  end
end

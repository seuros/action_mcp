# frozen_string_literal: true

class CreateActionMCPSSEEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :action_mcp_sse_events do |t|
      t.references :session, null: false, foreign_key: { to_table: :action_mcp_sessions }, index: true, type: :string
      t.integer :event_id, null: false
      t.text :data, null: false
      t.timestamps

      # Index for efficiently retrieving events after a given ID for a specific session
      t.index [ :session_id, :event_id ], unique: true
      t.index :created_at # For cleanup of old events
    end
  end
end

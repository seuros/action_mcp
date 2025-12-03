# frozen_string_literal: true

class RemoveSseSupport < ActiveRecord::Migration[8.1]
  def up
    # Drop SSE events table
    drop_table :action_mcp_sse_events, if_exists: true

    # Remove SSE counter from sessions
    remove_column :action_mcp_sessions, :sse_event_counter, if_exists: true
  end

  def down
    # Re-add sse_event_counter to sessions
    unless column_exists?(:action_mcp_sessions, :sse_event_counter)
      add_column :action_mcp_sessions, :sse_event_counter, :integer, default: 0, null: false
    end

    # Re-create SSE events table
    unless table_exists?(:action_mcp_sse_events)
      create_table :action_mcp_sse_events do |t|
        t.references :session, null: false, type: :string, foreign_key: { to_table: :action_mcp_sessions }
        t.integer :event_id, null: false
        t.text :data, null: false
        t.timestamps
      end

      add_index :action_mcp_sse_events, :created_at
      add_index :action_mcp_sse_events, [ :session_id, :event_id ], unique: true
    end
  end
end

# frozen_string_literal: true

# This migration comes from action_mcp (originally 20250512154359)
class ConsolidatedMigration < ActiveRecord::Migration[8.0]
  def change
    # Only create tables if they don't exist to avoid deleting existing data

    # Create sessions table
    unless table_exists?(:action_mcp_sessions)
      create_table :action_mcp_sessions, id: :string do |t|
        t.string :role, null: false, default: 'server', comment: 'The role of the session'
        t.string :status, null: false, default: 'pre_initialize'
        t.datetime :ended_at, comment: 'The time the session ended'
        t.string :protocol_version
        t.json :server_capabilities, comment: 'The capabilities of the server'
        t.json :client_capabilities, comment: 'The capabilities of the client'
        t.json :server_info, comment: 'The information about the server'
        t.json :client_info, comment: 'The information about the client'
        t.boolean :initialized, null: false, default: false
        t.integer :messages_count, null: false, default: 0
        t.integer :sse_event_counter, default: 0, null: false
        t.json :tool_registry, default: []
        t.json :prompt_registry, default: []
        t.json :resource_registry, default: []
        t.timestamps
      end
    end

    # Create session messages table
    unless table_exists?(:action_mcp_session_messages)
      create_table :action_mcp_session_messages do |t|
        t.references :session, null: false,
                               foreign_key: { to_table: :action_mcp_sessions,
                                              on_delete: :cascade,
                                              on_update: :cascade,
                                              name: 'fk_action_mcp_session_messages_session_id' }, type: :string
        t.string :direction, null: false, comment: 'The message recipient', default: 'client'
        t.string :message_type, null: false, comment: 'The type of the message'
        t.string :jsonrpc_id
        t.json :message_json
        t.boolean :is_ping, default: false, null: false, comment: 'Whether the message is a ping'
        t.boolean :request_acknowledged, default: false, null: false
        t.boolean :request_cancelled, null: false, default: false
        t.timestamps
      end
    end

    # Create session subscriptions table
    unless table_exists?(:action_mcp_session_subscriptions)
      create_table :action_mcp_session_subscriptions do |t|
        t.references :session,
                     null: false,
                     foreign_key: { to_table: :action_mcp_sessions, on_delete: :cascade },
                     type: :string
        t.string :uri, null: false
        t.datetime :last_notification_at
        t.timestamps
      end
    end

    # Create session resources table
    unless table_exists?(:action_mcp_session_resources)
      create_table :action_mcp_session_resources do |t|
        t.references :session,
                     null: false,
                     foreign_key: { to_table: :action_mcp_sessions, on_delete: :cascade },
                     type: :string
        t.string :uri, null: false
        t.string :name
        t.text :description
        t.string :mime_type, null: false
        t.boolean :created_by_tool, default: false
        t.datetime :last_accessed_at
        t.json :metadata
        t.timestamps
      end
    end

    # Create SSE events table
    unless table_exists?(:action_mcp_sse_events)
      create_table :action_mcp_sse_events do |t|
        t.references :session, null: false, foreign_key: { to_table: :action_mcp_sessions }, index: true, type: :string
        t.integer :event_id, null: false
        t.text :data, null: false
        t.timestamps

        # Index for efficiently retrieving events after a given ID for a specific session
        t.index %i[session_id event_id], unique: true
        t.index :created_at # For cleanup of old events
      end
    end

    # Add missing columns to existing tables if they exist

    # For action_mcp_sessions
    if table_exists?(:action_mcp_sessions)
      unless column_exists?(:action_mcp_sessions, :sse_event_counter)
        add_column :action_mcp_sessions, :sse_event_counter, :integer, default: 0, null: false
      end

      unless column_exists?(:action_mcp_sessions, :tool_registry)
        add_column :action_mcp_sessions, :tool_registry, :json, default: []
      end

      unless column_exists?(:action_mcp_sessions, :prompt_registry)
        add_column :action_mcp_sessions, :prompt_registry, :json, default: []
      end

      unless column_exists?(:action_mcp_sessions, :resource_registry)
        add_column :action_mcp_sessions, :resource_registry, :json, default: []
      end
    end

    # For action_mcp_session_messages
    return unless table_exists?(:action_mcp_session_messages)

    unless column_exists?(:action_mcp_session_messages, :is_ping)
      add_column :action_mcp_session_messages, :is_ping, :boolean, default: false, null: false,
                                                                   comment: 'Whether the message is a ping'
    end

    unless column_exists?(:action_mcp_session_messages, :request_acknowledged)
      add_column :action_mcp_session_messages, :request_acknowledged, :boolean, default: false, null: false
    end

    unless column_exists?(:action_mcp_session_messages, :request_cancelled)
      add_column :action_mcp_session_messages, :request_cancelled, :boolean, null: false, default: false
    end

    if column_exists?(:action_mcp_session_messages, :message_text)
      remove_column :action_mcp_session_messages, :message_text
    end

    return unless column_exists?(:action_mcp_session_messages, :direction)

    # SQLite3 doesn't support changing column comments
    if connection.adapter_name.downcase != 'sqlite'
      change_column_comment :action_mcp_session_messages, :direction, 'The message recipient'
    end
  end

  private

  def table_exists?(table_name)
    ActionMCP::ApplicationRecord.connection.table_exists?(table_name)
  end

  def column_exists?(table_name, column_name)
    ActionMCP::ApplicationRecord.connection.column_exists?(table_name, column_name)
  end
end

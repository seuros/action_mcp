# frozen_string_literal: true

class CreateActionMCPSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :action_mcp_sessions, id: :string do |t|
      t.string :role, null: false, default: 'server', comment: 'The role of the session'
      t.string :status, null: false, default: 'pre_initialize'
      t.datetime :ended_at, comment: 'The time the session ended'
      t.string :protocol_version
      t.jsonb :server_capabilities, comment: 'The capabilities of the server'
      t.jsonb :client_capabilities, comment: 'The capabilities of the client'
      t.jsonb :server_info, comment: 'The information about the server'
      t.jsonb :client_info, comment: 'The information about the client'
      t.boolean :initialized, null: false, default: false
      t.integer :messages_count, null: false, default: 0
      t.timestamps
    end

    create_table :action_mcp_session_messages do |t|
      t.references :session, null: false, foreign_key: { to_table: :action_mcp_sessions,
                                                         on_delete: :cascade,
                                                         on_update: :cascade,
                                                         name: 'fk_action_mcp_session_messages_session_id' }, type: :string
      t.string :direction, null: false, comment: 'The session direction', default: 'client'
      t.string :message_type, null: false, comment: 'The type of the message'
      t.string :jsonrpc_id
      t.string :message_text
      t.jsonb :message_json
      t.timestamps
    end
  end
end

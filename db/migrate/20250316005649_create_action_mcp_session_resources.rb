# frozen_string_literal: true

class CreateActionMCPSessionResources < ActiveRecord::Migration[8.0]
  def change
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
    change_column_comment :action_mcp_session_messages, :direction, 'The message recipient'
    change_column_comment :action_mcp_session_messages, :is_ping, 'Whether the message is a ping'
    rename_column :action_mcp_session_messages, :ping_acknowledged, :request_acknowledged
    add_column :action_mcp_session_messages, :request_cancelled, :boolean, null: false, default: false
  end
end

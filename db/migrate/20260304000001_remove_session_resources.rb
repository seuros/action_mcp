# frozen_string_literal: true

class RemoveSessionResources < ActiveRecord::Migration[8.1]
  def up
    drop_table :action_mcp_session_resources, if_exists: true
  end

  def down
    return if table_exists?(:action_mcp_session_resources)

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
end

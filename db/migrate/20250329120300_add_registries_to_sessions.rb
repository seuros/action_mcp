# frozen_string_literal: true

class AddRegistriesToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :action_mcp_sessions, :tool_registry, :jsonb, default: []
    add_column :action_mcp_sessions, :prompt_registry, :jsonb, default: []
    add_column :action_mcp_sessions, :resource_registry, :jsonb, default: []
  end
end

# frozen_string_literal: true

class AddOAuthToSessions < ActiveRecord::Migration[8.0]
  def change
    # Use jsonb for PostgreSQL, json for other databases (SQLite3, MySQL)
    json_type = connection.adapter_name.downcase == 'postgresql' ? :jsonb : :json

    add_column :action_mcp_sessions, :oauth_access_token, :string
    add_column :action_mcp_sessions, :oauth_refresh_token, :string
    add_column :action_mcp_sessions, :oauth_token_expires_at, :datetime
    add_column :action_mcp_sessions, :oauth_user_context, json_type
    add_column :action_mcp_sessions, :authentication_method, :string, default: "none"

    # Add indexes for performance
    add_index :action_mcp_sessions, :oauth_access_token, unique: true
    add_index :action_mcp_sessions, :oauth_token_expires_at
    add_index :action_mcp_sessions, :authentication_method
  end
end

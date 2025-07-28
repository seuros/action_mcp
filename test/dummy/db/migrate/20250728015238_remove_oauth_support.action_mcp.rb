# frozen_string_literal: true

# This migration comes from action_mcp (originally 20250727000001)
class RemoveOauthSupport < ActiveRecord::Migration[8.0]
  def change
    # Remove OAuth tables
    drop_table :action_mcp_oauth_clients, if_exists: true do |t|
      t.string :client_id, null: false
      t.string :client_secret
      t.string :client_name
      t.json :redirect_uris, default: []
      t.json :grant_types, default: [ "authorization_code" ]
      t.json :response_types, default: [ "code" ]
      t.string :token_endpoint_auth_method, default: "client_secret_basic"
      t.text :scope
      t.boolean :active, default: true
      t.integer :client_id_issued_at
      t.integer :client_secret_expires_at
      t.string :registration_access_token
      t.json :metadata, default: {}
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    drop_table :action_mcp_oauth_tokens, if_exists: true do |t|
      t.string :token, null: false
      t.string :token_type, null: false
      t.string :client_id, null: false
      t.string :user_id
      t.text :scope
      t.datetime :expires_at
      t.boolean :revoked, default: false
      t.string :redirect_uri
      t.string :code_challenge
      t.string :code_challenge_method
      t.string :access_token
      t.json :metadata, default: {}
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    # Remove OAuth columns from sessions table
    if table_exists?(:action_mcp_sessions)
      remove_column :action_mcp_sessions, :oauth_access_token, :string if column_exists?(:action_mcp_sessions, :oauth_access_token)
      remove_column :action_mcp_sessions, :oauth_refresh_token, :string if column_exists?(:action_mcp_sessions, :oauth_refresh_token)
      remove_column :action_mcp_sessions, :oauth_token_expires_at, :datetime if column_exists?(:action_mcp_sessions, :oauth_token_expires_at)
      remove_column :action_mcp_sessions, :oauth_user_context, :json if column_exists?(:action_mcp_sessions, :oauth_user_context)
    end
  end

  private

  def table_exists?(table_name)
    ActiveRecord::Base.connection.table_exists?(table_name)
  end

  def column_exists?(table_name, column_name)
    ActiveRecord::Base.connection.column_exists?(table_name, column_name)
  end
end

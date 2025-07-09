class CreateActionMCPOAuthTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :action_mcp_oauth_tokens do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :token_type, null: false # 'access_token', 'refresh_token', 'authorization_code'
      t.string :client_id, null: false
      t.string :user_id
      t.text :scope
      t.datetime :expires_at
      t.boolean :revoked, default: false

      # For authorization codes
      t.string :redirect_uri
      t.string :code_challenge
      t.string :code_challenge_method

      # For refresh tokens
      t.string :access_token # Reference to associated access token

      # Additional data - use JSON for database compatibility
      if connection.adapter_name.downcase.include?('postgresql')
        t.jsonb :metadata, default: {}
      else
        t.json :metadata, default: {}
      end

      t.timestamps
    end

    add_index :action_mcp_oauth_tokens, :token_type
    add_index :action_mcp_oauth_tokens, :client_id
    add_index :action_mcp_oauth_tokens, :user_id
    add_index :action_mcp_oauth_tokens, :expires_at
    add_index :action_mcp_oauth_tokens, :revoked
    add_index :action_mcp_oauth_tokens, [ :token_type, :expires_at ]
  end
end

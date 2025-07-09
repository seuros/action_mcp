class CreateActionMCPOAuthClients < ActiveRecord::Migration[7.2]
  def change
    create_table :action_mcp_oauth_clients do |t|
      t.string :client_id, null: false, index: { unique: true }
      t.string :client_secret
      t.string :client_name

      # Store arrays as JSON for database compatibility
      if connection.adapter_name.downcase.include?('postgresql')
        t.text :redirect_uris, array: true, default: []
        t.text :grant_types, array: true, default: [ "authorization_code" ]
        t.text :response_types, array: true, default: [ "code" ]
      else
        # For SQLite and other databases, use JSON
        t.json :redirect_uris, default: []
        t.json :grant_types, default: [ "authorization_code" ]
        t.json :response_types, default: [ "code" ]
      end

      t.string :token_endpoint_auth_method, default: "client_secret_basic"
      t.text :scope
      t.boolean :active, default: true

      # Registration metadata
      t.integer :client_id_issued_at
      t.integer :client_secret_expires_at

      # Additional metadata as JSON for database compatibility
      if connection.adapter_name.downcase.include?('postgresql')
        t.jsonb :metadata, default: {}
      else
        t.json :metadata, default: {}
      end

      t.timestamps
    end

    add_index :action_mcp_oauth_clients, :active
    add_index :action_mcp_oauth_clients, :client_id_issued_at
  end
end

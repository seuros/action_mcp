class CreateActionMCPSessionSubscriptions < ActiveRecord::Migration[8.0]
  def change
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
end

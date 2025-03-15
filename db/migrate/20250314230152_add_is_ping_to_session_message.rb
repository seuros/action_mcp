class AddIsPingToSessionMessage < ActiveRecord::Migration[8.0]
  def change
    add_column :action_mcp_session_messages, :is_ping, :boolean, default: false, null: false
    add_column :action_mcp_session_messages, :ping_acknowledged, :boolean, default: false, null: false
  end
end

class RemoveSessionMessageText < ActiveRecord::Migration[8.0]
  def up
    remove_column :action_mcp_session_messages, :message_text
  end
end

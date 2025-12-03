# frozen_string_literal: true

class AddProgressToSessionTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :action_mcp_session_tasks, :progress_percent, :integer, comment: "Task progress as percentage 0-100"
    add_column :action_mcp_session_tasks, :progress_message, :string, comment: "Human-readable progress message"
  end
end

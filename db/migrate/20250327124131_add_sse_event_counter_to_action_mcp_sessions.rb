# frozen_string_literal: true

class AddSSEEventCounterToActionMCPSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :action_mcp_sessions, :sse_event_counter, :integer, default: 0, null: false
  end
end

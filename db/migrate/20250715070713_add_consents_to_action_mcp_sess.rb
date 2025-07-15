# frozen_string_literal: true

class AddConsentsToActionMCPSess < ActiveRecord::Migration[8.0]
  def change
    add_column :action_mcp_sessions, :consents, :json, default: {}, null: false
  end
end

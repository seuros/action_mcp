# frozen_string_literal: true

class AddConsentsToActionMCPSess < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:action_mcp_sessions, :consents)

    add_column :action_mcp_sessions, :consents, :json, default: {}, null: false
  end
end

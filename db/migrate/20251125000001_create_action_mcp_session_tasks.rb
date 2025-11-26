# frozen_string_literal: true

class CreateActionMCPSessionTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :action_mcp_session_tasks, id: :string do |t|
      t.references :session, null: false,
                             foreign_key: { to_table: :action_mcp_sessions,
                                            on_delete: :cascade,
                                            on_update: :cascade,
                                            name: 'fk_action_mcp_session_tasks_session_id' },
                             type: :string
      t.string :status, null: false, default: 'working'
      t.string :status_message
      t.string :request_method, comment: 'e.g., tools/call, prompts/get'
      t.string :request_name, comment: 'e.g., tool name, prompt name'
      t.json :request_params, comment: 'Original request params'
      t.json :result_payload, comment: 'Final result data'
      t.integer :ttl, comment: 'Time to live in milliseconds'
      t.integer :poll_interval, comment: 'Suggested polling interval in milliseconds'
      t.datetime :last_updated_at, null: false

      t.timestamps

      t.index :status
      t.index %i[session_id status]
      t.index :created_at
    end
  end
end

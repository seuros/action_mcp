# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_14_230152) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_mcp_session_messages", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "direction", default: "client", null: false, comment: "The session direction"
    t.string "message_type", null: false, comment: "The type of the message"
    t.string "jsonrpc_id"
    t.string "message_text"
    t.jsonb "message_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_ping", default: false, null: false
    t.boolean "ping_acknowledged", default: false, null: false
    t.index ["session_id"], name: "index_action_mcp_session_messages_on_session_id"
  end

  create_table "action_mcp_sessions", id: :string, force: :cascade do |t|
    t.string "role", default: "server", null: false, comment: "The role of the session"
    t.string "status", default: "pre_initialize", null: false
    t.datetime "ended_at", comment: "The time the session ended"
    t.string "protocol_version"
    t.jsonb "server_capabilities", comment: "The capabilities of the server"
    t.jsonb "client_capabilities", comment: "The capabilities of the client"
    t.jsonb "server_info", comment: "The information about the server"
    t.jsonb "client_info", comment: "The information about the client"
    t.boolean "initialized", default: false, null: false
    t.integer "messages_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "action_mcp_session_messages", "action_mcp_sessions", column: "session_id", name: "fk_action_mcp_session_messages_session_id", on_update: :cascade, on_delete: :cascade
end

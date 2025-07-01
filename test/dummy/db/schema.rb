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

ActiveRecord::Schema[8.0].define(version: 2025_06_24_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_mcp_session_messages", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "direction", default: "client", null: false, comment: "The message recipient"
    t.string "message_type", null: false, comment: "The type of the message"
    t.string "jsonrpc_id"
    t.json "message_json"
    t.boolean "is_ping", default: false, null: false, comment: "Whether the message is a ping"
    t.boolean "request_acknowledged", default: false, null: false
    t.boolean "request_cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_action_mcp_session_messages_on_session_id"
  end

  create_table "action_mcp_session_resources", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "uri", null: false
    t.string "name"
    t.text "description"
    t.string "mime_type", null: false
    t.boolean "created_by_tool", default: false
    t.datetime "last_accessed_at"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_action_mcp_session_resources_on_session_id"
  end

  create_table "action_mcp_session_subscriptions", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "uri", null: false
    t.datetime "last_notification_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_action_mcp_session_subscriptions_on_session_id"
  end

  create_table "action_mcp_sessions", id: :string, force: :cascade do |t|
    t.string "role", default: "server", null: false, comment: "The role of the session"
    t.string "status", default: "pre_initialize", null: false
    t.datetime "ended_at", comment: "The time the session ended"
    t.string "protocol_version"
    t.json "server_capabilities", comment: "The capabilities of the server"
    t.json "client_capabilities", comment: "The capabilities of the client"
    t.json "server_info", comment: "The information about the server"
    t.json "client_info", comment: "The information about the client"
    t.boolean "initialized", default: false, null: false
    t.integer "messages_count", default: 0, null: false
    t.integer "sse_event_counter", default: 0, null: false
    t.json "tool_registry", default: []
    t.json "prompt_registry", default: []
    t.json "resource_registry", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "oauth_access_token"
    t.string "oauth_refresh_token"
    t.datetime "oauth_token_expires_at"
    t.json "oauth_user_context"
    t.string "authentication_method", default: "none"
    t.index ["authentication_method"], name: "index_action_mcp_sessions_on_authentication_method"
    t.index ["oauth_access_token"], name: "index_action_mcp_sessions_on_oauth_access_token", unique: true
    t.index ["oauth_token_expires_at"], name: "index_action_mcp_sessions_on_oauth_token_expires_at"
  end

  create_table "action_mcp_sse_events", force: :cascade do |t|
    t.string "session_id", null: false
    t.integer "event_id", null: false
    t.text "data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_action_mcp_sse_events_on_created_at"
    t.index ["session_id", "event_id"], name: "index_action_mcp_sse_events_on_session_id_and_event_id", unique: true
    t.index ["session_id"], name: "index_action_mcp_sse_events_on_session_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "action_mcp_session_messages", "action_mcp_sessions", column: "session_id", name: "fk_action_mcp_session_messages_session_id", on_update: :cascade, on_delete: :cascade
  add_foreign_key "action_mcp_session_resources", "action_mcp_sessions", column: "session_id", on_delete: :cascade
  add_foreign_key "action_mcp_session_subscriptions", "action_mcp_sessions", column: "session_id", on_delete: :cascade
  add_foreign_key "action_mcp_sse_events", "action_mcp_sessions", column: "session_id"
end

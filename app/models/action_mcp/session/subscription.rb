# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_session_subscriptions"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", pk = true, null = false },
#   { name = "created_at", type = "datetime", null = false },
#   { name = "last_notification_at", type = "datetime" },
#   { name = "session_id", type = "string", null = false },
#   { name = "updated_at", type = "datetime", null = false },
#   { name = "uri", type = "string", null = false }
# ]
#
# indexes = [
#   { name = "index_action_mcp_session_subscriptions_on_session_id", columns = ["session_id"] }
# ]
#
# foreign_keys = [
#   { column = "session_id", references_table = "action_mcp_sessions", references_column = "id", on_delete = "cascade" }
# ]
#
# notes = ["session:COUNTER_CACHE", "session_id:LIMIT", "uri:LIMIT"]
# <rails-lens:schema:end>
module ActionMCP
  class Session
    #
    # Represents a client's subscription to a resource for real-time updates.
    # Its role is to store the URI of the resource being subscribed to and track the last time a notification was sent for the subscription.
    # All Subscriptions are deleted when the session is closed.
    class Subscription < ApplicationRecord
      belongs_to :session,
                 class_name: "ActionMCP::Session",
                 inverse_of: :subscriptions
    end
  end
end

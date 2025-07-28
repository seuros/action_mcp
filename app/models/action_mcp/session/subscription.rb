# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_session_subscriptions"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", primary_key = true, nullable = false },
#   { name = "session_id", type = "string", nullable = false },
#   { name = "uri", type = "string", nullable = false },
#   { name = "last_notification_at", type = "datetime", nullable = true },
#   { name = "created_at", type = "datetime", nullable = false },
#   { name = "updated_at", type = "datetime", nullable = false }
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
# == Notes
# - Consider adding counter cache for 'session'
# - String column 'session_id' has no length limit - consider adding one
# - String column 'uri' has no length limit - consider adding one
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

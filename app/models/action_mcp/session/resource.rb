# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_session_resources"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", primary_key = true, nullable = false },
#   { name = "session_id", type = "string", nullable = false },
#   { name = "uri", type = "string", nullable = false },
#   { name = "name", type = "string", nullable = true },
#   { name = "description", type = "text", nullable = true },
#   { name = "mime_type", type = "string", nullable = false },
#   { name = "created_by_tool", type = "boolean", nullable = true, default = "0" },
#   { name = "last_accessed_at", type = "datetime", nullable = true },
#   { name = "metadata", type = "json", nullable = true },
#   { name = "created_at", type = "datetime", nullable = false },
#   { name = "updated_at", type = "datetime", nullable = false }
# ]
#
# indexes = [
#   { name = "index_action_mcp_session_resources_on_session_id", columns = ["session_id"] }
# ]
#
# foreign_keys = [
#   { column = "session_id", references_table = "action_mcp_sessions", references_column = "id", on_delete = "cascade" }
# ]
#
# == Notes
# - Association 'session' should specify inverse_of
# - Column 'name' should probably have NOT NULL constraint
# - Column 'description' should probably have NOT NULL constraint
# - Column 'created_by_tool' should probably have NOT NULL constraint
# - Column 'metadata' should probably have NOT NULL constraint
# - String column 'session_id' has no length limit - consider adding one
# - String column 'uri' has no length limit - consider adding one
# - String column 'name' has no length limit - consider adding one
# - String column 'mime_type' has no length limit - consider adding one
# - Large text column 'description' is frequently queried - consider separate storage
# - Column 'mime_type' is commonly used in queries - consider adding an index
# <rails-lens:schema:end>
module ActionMCP
  class Session
    #
    # Represents a resource associated with an MCP session.
    # Its role is to store information about a resource, such as its URI, MIME type, description,
    # and any associated metadata. It also tracks whether the resource was created by a tool and the last time it was accessed.
    class Resource < ApplicationRecord
      belongs_to :session
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module OAuth
    # Load OAuth components
    autoload :Error, "action_mcp/oauth/error"
    autoload :Provider, "action_mcp/oauth/provider"
    autoload :Middleware, "action_mcp/oauth/middleware"
    autoload :MemoryStorage, "action_mcp/oauth/memory_storage"
    autoload :ActiveRecordStorage, "action_mcp/oauth/active_record_storage"
  end
end

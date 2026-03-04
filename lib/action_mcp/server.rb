# frozen_string_literal: true

module ActionMCP
  # Module for server-related functionality.
  module Server
    module_function

    # Access the session store
    def session_store
      current_type = ActionMCP.configuration.server_session_store_type
      if @session_store.nil? || @session_store_type != current_type
        @session_store_type = current_type
        @session_store = SessionStoreFactory.create(current_type)
      end
      @session_store
    end
  end
end

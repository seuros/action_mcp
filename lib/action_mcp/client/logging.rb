# frozen_string_literal: true

module ActionMCP
  module Client
    module Logging
      # Set the client's logging level
      # @param level [String] Logging level (debug, info, warning, error, etc.)
      # @return [Boolean] Success status
      def set_logging_level(level)
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("client/setLoggingLevel",
                                params: { level: level },
                                id: request_id
        )
      end
    end
  end
end

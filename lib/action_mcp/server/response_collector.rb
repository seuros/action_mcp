# frozen_string_literal: true

module ActionMCP
  module Server
    # Module to collect responses when operating in :return mode
    module ResponseCollector
      attr_reader :collected_responses

      def initialize_response_collector
        @collected_responses = []
      end

      # Collect messages for the HTTP response while retaining the session's
      # complete wire history. Server-initiated requests cannot be placed in
      # the empty 202 response required for an incoming notification, so the
      # generated request must not be silently discarded.
      def write_message(message)
        if messaging_mode == :return
          @collected_responses ||= []
          @collected_responses << message
          super
          message
        else
          super
        end
      end

      # Get all collected responses
      def get_collected_responses
        @collected_responses || []
      end

      # Get the last response (useful for single request/response scenarios)
      def get_last_response
        @collected_responses&.last
      end

      # Clear collected responses
      def clear_collected_responses
        @collected_responses = []
      end
    end
  end
end

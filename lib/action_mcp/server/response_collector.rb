# frozen_string_literal: true

module ActionMCP
  module Server
    # Module to collect responses when operating in :return mode
    module ResponseCollector
      attr_reader :collected_responses

      def initialize_response_collector
        @collected_responses = []
      end

      # Override write_message to collect responses instead of writing them
      def write_message(message)
        if messaging_mode == :return
          @collected_responses ||= []
          @collected_responses << message
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

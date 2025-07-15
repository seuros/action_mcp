# frozen_string_literal: true

module ActionMCP
  module Server
    # Handles elicitation requests from the server to the client
    module Elicitation
      # Sends an elicitation request to the client to gather additional information
      # @param request_id [String, Integer] The JSON-RPC request ID
      # @param message [String] The message to present to the user
      # @param requested_schema [Hash] The schema for the requested information
      # @return [Hash] The elicitation response
      def send_elicitation_request(request_id, message:, requested_schema:)
        # Validate the requested schema
        validate_elicitation_schema!(requested_schema)

        params = {
          message: message,
          requestedSchema: requested_schema
        }

        send_jsonrpc_request(request_id, method: "elicitation/create", params: params)
      end

      private

      # Validates that the requested schema follows the elicitation constraints
      # Only allows primitive types without nesting
      def validate_elicitation_schema!(schema)
        unless schema.is_a?(Hash) && schema[:type] == "object"
          raise ArgumentError, "Elicitation schema must be an object type"
        end

        properties = schema[:properties]
        raise ArgumentError, "Elicitation schema must have properties" unless properties.is_a?(Hash)

        properties.each do |key, prop_schema|
          validate_primitive_schema!(key, prop_schema)
        end
      end

      # Validates individual property schemas are primitive types
      def validate_primitive_schema!(key, schema)
        raise ArgumentError, "Property '#{key}' must have a schema definition" unless schema.is_a?(Hash)

        type = schema[:type]
        case type
        when "string"
          # Valid string schema, check for enums
          raise ArgumentError, "Property '#{key}' enum must be an array" if schema[:enum] && !schema[:enum].is_a?(Array)
        when "number", "integer", "boolean"
          # Valid primitive types
        else
          raise ArgumentError, "Property '#{key}' must be a primitive type (string, number, integer, boolean)"
        end
      end
    end
  end
end

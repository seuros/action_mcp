# frozen_string_literal: true

module ActionMCP
  # Shared utilities for JSON Schema manipulation
  module SchemaHelpers
    private

    # Helper method to add additionalProperties to a schema hash
    # @param schema [Hash] The schema hash to modify
    # @param additional_properties_value [Boolean, Hash, nil] The additionalProperties configuration
    # @return [Hash] The modified schema hash
    def add_additional_properties_to_schema(schema, additional_properties_value)
      return schema if additional_properties_value.nil?

      # Use HashWithIndifferentAccess for checking, but modify original schema
      indifferent_schema = schema.with_indifferent_access

      # Only add additionalProperties if this is a typed schema
      return schema unless indifferent_schema[:type]

      additional_props = case additional_properties_value
      when true then {}
      when false then false
      when Hash then additional_properties_value
      end

      # Add to original schema using its key style (symbol or string)
      if schema.key?(:type) || schema.key?("type")
        key = schema.key?(:type) ? :additionalProperties : "additionalProperties"
        schema[key] = additional_props
      end

      schema
    end
  end
end

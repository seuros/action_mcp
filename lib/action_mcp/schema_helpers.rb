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

      # Work with indifferent access for checking, but preserve original schema structure
      indifferent_schema = schema.with_indifferent_access

      # Only add additionalProperties if this is a typed schema
      return schema unless indifferent_schema[:type]

      additional_props = case additional_properties_value
      when true then {}
      when false then false
      when Hash then additional_properties_value
      end

      # Set using the same key type as the original schema to preserve structure
      if schema.key?(:type)
        schema[:additionalProperties] = additional_props
      elsif schema.key?("type")
        schema["additionalProperties"] = additional_props
      end

      schema
    end
  end
end

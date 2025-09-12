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

      # Determine if schema uses symbol or string keys by checking for :type vs "type"
      uses_symbol_keys = schema.key?(:type)
      uses_string_keys = schema.key?("type")

      # Only add additionalProperties if this is a typed schema
      return schema unless uses_symbol_keys || uses_string_keys

      additional_props_value = case additional_properties_value
      when true then {}
      when false then false
      when Hash then additional_properties_value
      end

      # Set additionalProperties using the same key type as the schema
      if uses_symbol_keys
        schema[:additionalProperties] = additional_props_value
      elsif uses_string_keys
        schema["additionalProperties"] = additional_props_value
      end

      schema
    end
  end
end

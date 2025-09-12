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

      if additional_properties_value == true
        schema[:additionalProperties] = {} if schema.key?(:type)
        schema["additionalProperties"] = {} if schema.key?("type")
      elsif additional_properties_value == false
        schema[:additionalProperties] = false if schema.key?(:type)
        schema["additionalProperties"] = false if schema.key?("type")
      elsif additional_properties_value.is_a?(Hash)
        schema[:additionalProperties] = additional_properties_value if schema.key?(:type)
        schema["additionalProperties"] = additional_properties_value if schema.key?("type")
      end

      schema
    end
  end
end

# frozen_string_literal: true

require_relative "schema_helpers"

module ActionMCP
  # DSL builder for creating output JSON Schema from Ruby-like syntax
  # Unlike SchemaBuilder, this preserves nested structure for validation
  class OutputSchemaBuilder
    include SchemaHelpers

    attr_reader :properties, :required

    def initialize
      @properties = {}
      @required = []
    end

    # Define a property with specified type
    # @param name [Symbol] Property name
    # @param type [String] JSON Schema type
    # @param required [Boolean] Whether the property is required
    # @param description [String] Property description
    # @param options [Hash] Additional JSON Schema options
    def property(name, type: "string", required: false, description: nil, **options)
      schema = { "type" => type }
      schema["description"] = description if description
      schema.merge!(options) if options.any?

      @properties[name.to_s] = schema
      @required << name.to_s if required

      name.to_s
    end

    # Define a string property
    def string(name = nil, required: false, description: nil, format: nil, enum: nil,
               default: nil, min_length: nil, max_length: nil)
      schema = { "type" => "string" }
      schema["description"] = description if description
      schema["format"] = format if format
      schema["enum"] = enum if enum
      schema["default"] = default if default
      schema["minLength"] = min_length if min_length
      schema["maxLength"] = max_length if max_length

      if name
        @properties[name.to_s] = schema
        @required << name.to_s if required
        name.to_s
      else
        # Return schema for use in array items or other contexts
        schema
      end
    end

    # Define a number property
    def number(name, required: false, description: nil, minimum: nil,
               maximum: nil, default: nil)
      schema = { "type" => "number" }
      schema["description"] = description if description
      schema["minimum"] = minimum if minimum
      schema["maximum"] = maximum if maximum
      schema["default"] = default if default

      @properties[name.to_s] = schema
      @required << name.to_s if required

      name.to_s
    end

    # Define a boolean property
    def boolean(name, required: false, description: nil, default: nil)
      schema = { "type" => "boolean" }
      schema["description"] = description if description
      schema["default"] = default unless default.nil?

      @properties[name.to_s] = schema
      @required << name.to_s if required

      name.to_s
    end

    # Define an array property
    # @param name [Symbol] Array property name
    # @param description [String] Property description
    # @param min_items [Integer] Minimum number of items
    # @param max_items [Integer] Maximum number of items
    # @param items [Hash] Items schema (if not using block)
    # @param block [Proc] Block defining item schema
    def array(name, description: nil, min_items: nil, max_items: nil, items: nil, &block)
      schema = { "type" => "array" }
      schema["description"] = description if description
      schema["minItems"] = min_items if min_items
      schema["maxItems"] = max_items if max_items

      if block_given?
        # Create nested builder for items
        item_builder = OutputSchemaBuilder.new
        result = item_builder.instance_eval(&block)

        # If the block returned a schema directly (e.g., from string()),
        # use that. Otherwise, build an object schema from properties.
        if result.is_a?(Hash) && result["type"]
          schema["items"] = result
        elsif item_builder.properties.empty?
          # Block didn't define properties, assume string items
          schema["items"] = { "type" => "string" }
        else
          # Block defined object properties
          item_schema = {
            "type" => "object",
            "properties" => item_builder.properties
          }
          item_schema["required"] = item_builder.required if item_builder.required.any?
          schema["items"] = item_schema
        end
      elsif items
        schema["items"] = items
      else
        # Default to string items
        schema["items"] = { "type" => "string" }
      end

      @properties[name.to_s] = schema

      name.to_s
    end

    # Define an object property
    # @param name [Symbol, nil] Object property name. If nil, returns schema directly (for array items)
    # @param required [Boolean] Whether the object is required
    # @param description [String] Property description
    # @param additional_properties [Boolean, Hash] Whether to allow additional properties
    # @param block [Proc] Block defining object properties
    def object(name = nil, required: false, description: nil, additional_properties: nil, &block)
      raise ArgumentError, "Object definition requires a block" unless block_given?

      # Create nested builder for object properties
      object_builder = OutputSchemaBuilder.new
      object_builder.instance_eval(&block)

      schema = {
        "type" => "object",
        "properties" => object_builder.properties
      }
      schema["description"] = description if description
      schema["required"] = object_builder.required if object_builder.required.any?

      # Add additionalProperties if specified
      add_additional_properties_to_schema(schema, additional_properties)

      if name
        @properties[name.to_s] = schema
        @required << name.to_s if required
        name.to_s
      else
        # Return schema directly for use in array items
        schema
      end
    end

    # Set additionalProperties for the root schema
    # @param enabled [Boolean, Hash] true to allow any additional properties,
    #   false to disallow them, or a Hash for typed additional properties
    def additional_properties(enabled = nil)
      if enabled.nil?
        @additional_properties
      else
        @additional_properties = enabled
      end
    end

    # Generate the final JSON Schema
    def to_json_schema
      schema = {
        "type" => "object",
        "properties" => @properties
      }

      schema["required"] = @required.uniq if @required.any?

      # Add additionalProperties if configured
      add_additional_properties_to_schema(schema, @additional_properties)

      schema
    end
  end
end

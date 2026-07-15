# frozen_string_literal: true

require "json_schemer"

module ActionMCP
  module SchemaValidator
    DEFAULT_DIALECT = "https://json-schema.org/draft/2020-12/schema"

    module_function

    def compile(schema, context: "JSON Schema")
      normalized_schema = normalize(schema)
      schema_errors = JSONSchemer.validate_schema(normalized_schema).to_a

      if schema_errors.any?
        raise ArgumentError, "Invalid #{context}: #{error_messages(schema_errors).join(', ')}"
      end

      JSONSchemer.schema(normalized_schema)
    rescue JSONSchemer::UnknownRef => e
      raise ArgumentError, "Invalid #{context}: unknown schema dialect or reference #{e.message.inspect}"
    end

    def validate(schemer, value)
      schemer.validate(normalize(value)).to_a
    end

    def error_messages(errors)
      errors.filter_map { |error| error["error"] }.uniq
    end

    def normalize(value)
      case value
      when Hash
        value.deep_stringify_keys
      when Array
        value.map { |item| normalize(item) }
      else
        value
      end
    end
  end
end

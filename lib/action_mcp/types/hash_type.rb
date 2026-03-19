# frozen_string_literal: true

module ActionMCP
  module Types
    # Custom ActiveModel type for JSON Schema "object" properties.
    # Preserves Hash values without coercion.
    class HashType < ActiveModel::Type::Value
      def type
        :hash
      end

      def cast(value)
        case value
        when Hash then value
        when String
          begin
            parsed = JSON.parse(value)
            parsed.is_a?(Hash) ? parsed : nil
          rescue JSON::ParserError
            nil
          end
        end
      end

      def serialize(value)
        cast(value)
      end

      def deserialize(value)
        cast(value)
      end
    end
  end
end

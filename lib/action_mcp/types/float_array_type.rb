# frozen_string_literal: true

module ActionMCP
  module Types
    # Custom ActiveModel type for handling arrays of floating point numbers
    class FloatArrayType < ActiveModel::Type::Value
      def type
        :float_array
      end

      def cast(value)
        return [] if value.nil?
        return value if value.is_a?(Array) && value.all? { |v| v.is_a?(Float) }

        Array(value).map do |v|
          case v
          when Float then v
          when Numeric then v.to_f
          when String
            case v.downcase
            when "infinity", "+infinity"
              Float::INFINITY
            when "-infinity"
              -Float::INFINITY
            when "nan"
              Float::NAN
            else
              Float(v) rescue nil
            end
          else
            nil
          end
        end.compact
      end

      def serialize(value)
        cast(value)
      end

      def deserialize(value)
        return value if value.is_a?(Array)
        return [] if value.nil?

        # Handle JSON deserialization
        if value.is_a?(String)
          begin
            parsed = JSON.parse(value)
            cast(parsed)
          rescue JSON::ParserError
            []
          end
        else
          cast(value)
        end
      end
    end
  end
end

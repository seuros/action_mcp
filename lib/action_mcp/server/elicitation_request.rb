# frozen_string_literal: true

module ActionMCP
  module Server
    # Value object for form-mode elicitation requests.
    # Validates that the requested schema follows MCP constraints:
    # flat object with primitive properties only.
    class ElicitationRequest
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :message, :string
      attribute :requested_schema # Hash
      attribute :_meta            # Hash, optional

      validates :message, presence: true
      validates :requested_schema, presence: true
      validate :schema_must_be_object_with_properties, if: -> { requested_schema.present? }
      validate :properties_must_be_primitive, if: -> { errors[:requested_schema].empty? && requested_schema.present? }

      # Wrap incoming schema in indifferent access so both string and symbol keys work.
      def requested_schema=(value)
        super(value.is_a?(Hash) ? value.with_indifferent_access : value)
      end

      # @return [Hash] JSON-RPC params for elicitation/create
      def to_params
        params = { mode: "form", message: message, requestedSchema: requested_schema.to_hash.deep_symbolize_keys }
        params[:_meta] = _meta if _meta.present?
        params
      end

      # Validates and raises ArgumentError on failure (preserving public API).
      # Named assert_valid! to avoid shadowing ActiveModel#validate!
      def assert_valid!
        return if valid?

        raise ArgumentError, errors.full_messages.join(", ")
      end

      private

      def schema_must_be_object_with_properties
        unless requested_schema.is_a?(Hash) && requested_schema[:type] == "object"
          errors.add(:requested_schema, "must be an object type")
          return
        end

        properties = requested_schema[:properties]
        errors.add(:requested_schema, "must have properties") unless properties.is_a?(Hash)
      end

      def properties_must_be_primitive
        properties = requested_schema[:properties]
        return unless properties.is_a?(Hash)

        properties.each do |key, prop_schema|
          validate_primitive_property(key, prop_schema)
        end
      end

      def validate_primitive_property(key, schema)
        unless schema.is_a?(Hash)
          errors.add(:requested_schema, "property '#{key}' must have a schema definition")
          return
        end

        case schema[:type]
        when "string"
          validate_string_enum(key, schema)
        when "number", "integer", "boolean"
          # valid primitive types
        when "array"
          validate_enum_array(key, schema)
        else
          errors.add(:requested_schema,
            "property '#{key}' must be a primitive type (string, number, integer, boolean) or enum array")
        end
      end

      def validate_string_enum(key, schema)
        if schema[:enum] && !schema[:enum].is_a?(Array)
          errors.add(:requested_schema, "property '#{key}' enum must be an array")
        end
      end

      def validate_enum_array(key, schema)
        items = schema[:items]
        unless items.is_a?(Hash)
          errors.add(:requested_schema, "property '#{key}' array must have items schema")
          return
        end

        unless items[:enum].is_a?(Array) || items[:anyOf].is_a?(Array)
          errors.add(:requested_schema, "property '#{key}' array items must be an enum (enum or anyOf)")
        end
      end
    end
  end
end

# frozen_string_literal: true

require "json_schemer"

module ActionMCP
  module Server
    # Value object for form-mode elicitation requests.
    # Validates that the requested schema follows MCP constraints:
    # flat object with primitive properties only.
    class ElicitationRequest
      include ActiveModel::Model
      include ActiveModel::Attributes

      STRING_SCHEMA = {
        "type" => "object",
        "required" => [ "type" ],
        "properties" => {
          "type" => { "const" => "string" },
          "title" => { "type" => "string" },
          "description" => { "type" => "string" },
          "default" => { "type" => "string" },
          "format" => { "enum" => %w[date date-time email uri] },
          "minLength" => { "type" => "integer" },
          "maxLength" => { "type" => "integer" }
        }
      }.freeze

      NUMBER_SCHEMA = {
        "type" => "object",
        "required" => [ "type" ],
        "properties" => {
          "type" => { "enum" => %w[integer number] },
          "title" => { "type" => "string" },
          "description" => { "type" => "string" },
          "default" => { "type" => "integer" },
          "minimum" => { "type" => "integer" },
          "maximum" => { "type" => "integer" }
        }
      }.freeze

      BOOLEAN_SCHEMA = {
        "type" => "object",
        "required" => [ "type" ],
        "properties" => {
          "type" => { "const" => "boolean" },
          "title" => { "type" => "string" },
          "description" => { "type" => "string" },
          "default" => { "type" => "boolean" }
        }
      }.freeze

      ENUM_OPTION_SCHEMA = {
        "type" => "object",
        "required" => %w[const title],
        "properties" => {
          "const" => { "type" => "string" },
          "title" => { "type" => "string" }
        }
      }.freeze

      UNTITLED_MULTI_SELECT_SCHEMA = {
        "type" => "object",
        "required" => %w[items type],
        "properties" => {
          "type" => { "const" => "array" },
          "title" => { "type" => "string" },
          "description" => { "type" => "string" },
          "default" => { "type" => "array", "items" => { "type" => "string" } },
          "minItems" => { "type" => "integer" },
          "maxItems" => { "type" => "integer" },
          "items" => {
            "type" => "object",
            "required" => %w[enum type],
            "properties" => {
              "type" => { "const" => "string" },
              "enum" => { "type" => "array", "items" => { "type" => "string" } }
            }
          }
        }
      }.freeze

      TITLED_MULTI_SELECT_SCHEMA = {
        "type" => "object",
        "required" => %w[items type],
        "properties" => {
          "type" => { "const" => "array" },
          "title" => { "type" => "string" },
          "description" => { "type" => "string" },
          "default" => { "type" => "array", "items" => { "type" => "string" } },
          "minItems" => { "type" => "integer" },
          "maxItems" => { "type" => "integer" },
          "items" => {
            "type" => "object",
            "required" => [ "anyOf" ],
            "properties" => {
              "anyOf" => { "type" => "array", "items" => ENUM_OPTION_SCHEMA }
            }
          }
        }
      }.freeze

      REQUESTED_SCHEMA = {
        "type" => "object",
        "required" => %w[properties type],
        "properties" => {
          "$schema" => { "type" => "string" },
          "type" => { "const" => "object" },
          "required" => { "type" => "array", "items" => { "type" => "string" } },
          "properties" => {
            "type" => "object",
            "additionalProperties" => {
              "anyOf" => [
                STRING_SCHEMA,
                NUMBER_SCHEMA,
                BOOLEAN_SCHEMA,
                UNTITLED_MULTI_SELECT_SCHEMA,
                TITLED_MULTI_SELECT_SCHEMA
              ]
            }
          }
        }
      }.freeze
      REQUESTED_SCHEMA_SCHEMER = JSONSchemer.schema(REQUESTED_SCHEMA)
      TASK_SCHEMA = {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "ttl" => { "type" => "integer" }
        }
      }.freeze
      TASK_SCHEMER = JSONSchemer.schema(TASK_SCHEMA)

      attribute :message, :string
      attribute :requested_schema # Hash
      attribute :_meta            # Hash, optional
      attribute :task             # TaskMetadata, optional

      validates :message, presence: true
      validates :requested_schema, presence: true
      validate :requested_schema_must_match_protocol, if: -> { requested_schema.present? }
      validate :meta_must_be_object, if: -> { _meta.present? }
      validate :task_must_match_protocol, unless: -> { task.nil? }

      # Wrap incoming schema in indifferent access so both string and symbol keys work.
      def requested_schema=(value)
        super(value.is_a?(Hash) ? value.with_indifferent_access : value)
      end

      # @return [Hash] JSON-RPC params for elicitation/create
      def to_params
        params = { mode: "form", message: message, requestedSchema: requested_schema.to_hash.deep_symbolize_keys }
        params[:_meta] = _meta if _meta.present?
        params[:task] = task unless task.nil?
        params
      end

      # Validates and raises ArgumentError on failure (preserving public API).
      # Named assert_valid! to avoid shadowing ActiveModel#validate!
      def assert_valid!
        return if valid?

        raise ArgumentError, errors.full_messages.join(", ")
      end

      private

      def requested_schema_must_match_protocol
        validation_errors = REQUESTED_SCHEMA_SCHEMER.validate(requested_schema.to_h.deep_stringify_keys).to_a
        return if validation_errors.empty?

        pointers = validation_errors.map { |error| error["data_pointer"].presence || "/" }.uniq
        errors.add(:requested_schema, "must match MCP 2025-11-25 at #{pointers.join(', ')}")
      end

      def meta_must_be_object
        errors.add(:_meta, "must be an object") unless _meta.is_a?(Hash)
      end

      def task_must_match_protocol
        errors.add(:task, "must match MCP 2025-11-25 TaskMetadata") unless
          task.is_a?(Hash) && TASK_SCHEMER.valid?(task.deep_stringify_keys)
      end
    end
  end
end

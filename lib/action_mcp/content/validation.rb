# frozen_string_literal: true

require "addressable/uri"
require "base64"
require "json"
require "json_schemer"
require "active_support/core_ext/object/deep_dup"

module ActionMCP
  module Content
    # Stable MCP wire-shape validation shared by content and response value objects.
    module Validation
      META_PROPERTY = {
        "_meta" => { "type" => "object" }
      }.freeze

      ANNOTATIONS = {
        "type" => "object",
        "properties" => {
          "audience" => {
            "type" => "array",
            "items" => { "type" => "string", "enum" => %w[assistant user] }
          },
          "lastModified" => { "type" => "string" },
          "priority" => { "type" => "number", "minimum" => 0, "maximum" => 1 }
        }
      }.freeze

      ICON = {
        "type" => "object",
        "required" => [ "src" ],
        "properties" => {
          "src" => { "type" => "string", "format" => "uri" },
          "mimeType" => { "type" => "string" },
          "sizes" => { "type" => "array", "items" => { "type" => "string" } },
          "theme" => { "type" => "string", "enum" => %w[dark light] }
        }
      }.freeze

      DEFINITIONS = {
        "Annotations" => ANNOTATIONS,
        "Icon" => ICON,
        "TextContent" => {
          "type" => "object",
          "required" => %w[text type],
          "properties" => META_PROPERTY.merge(
            "annotations" => { "$ref" => "#/$defs/Annotations" },
            "text" => { "type" => "string" },
            "type" => { "type" => "string", "const" => "text" }
          )
        },
        "ImageContent" => {
          "type" => "object",
          "required" => %w[data mimeType type],
          "properties" => META_PROPERTY.merge(
            "annotations" => { "$ref" => "#/$defs/Annotations" },
            "data" => { "type" => "string", "format" => "byte" },
            "mimeType" => { "type" => "string" },
            "type" => { "type" => "string", "const" => "image" }
          )
        },
        "AudioContent" => {
          "type" => "object",
          "required" => %w[data mimeType type],
          "properties" => META_PROPERTY.merge(
            "annotations" => { "$ref" => "#/$defs/Annotations" },
            "data" => { "type" => "string", "format" => "byte" },
            "mimeType" => { "type" => "string" },
            "type" => { "type" => "string", "const" => "audio" }
          )
        },
        "TextResourceContents" => {
          "type" => "object",
          "required" => %w[text uri],
          "properties" => META_PROPERTY.merge(
            "mimeType" => { "type" => "string" },
            "text" => { "type" => "string" },
            "uri" => { "type" => "string", "format" => "uri" }
          )
        },
        "BlobResourceContents" => {
          "type" => "object",
          "required" => %w[blob uri],
          "properties" => META_PROPERTY.merge(
            "blob" => { "type" => "string", "format" => "byte" },
            "mimeType" => { "type" => "string" },
            "uri" => { "type" => "string", "format" => "uri" }
          )
        },
        "EmbeddedResource" => {
          "type" => "object",
          "required" => %w[resource type],
          "properties" => META_PROPERTY.merge(
            "annotations" => { "$ref" => "#/$defs/Annotations" },
            "resource" => {
              "anyOf" => [
                { "$ref" => "#/$defs/TextResourceContents" },
                { "$ref" => "#/$defs/BlobResourceContents" }
              ]
            },
            "type" => { "type" => "string", "const" => "resource" }
          )
        },
        "ResourceLink" => {
          "type" => "object",
          "required" => %w[name type uri],
          "properties" => META_PROPERTY.merge(
            "annotations" => { "$ref" => "#/$defs/Annotations" },
            "description" => { "type" => "string" },
            "icons" => { "type" => "array", "items" => { "$ref" => "#/$defs/Icon" } },
            "mimeType" => { "type" => "string" },
            "name" => { "type" => "string" },
            "size" => { "type" => "integer" },
            "title" => { "type" => "string" },
            "type" => { "type" => "string", "const" => "resource_link" },
            "uri" => { "type" => "string", "format" => "uri" }
          )
        },
        "ContentBlock" => {
          "anyOf" => %w[TextContent ImageContent AudioContent ResourceLink EmbeddedResource].map do |name|
            { "$ref" => "#/$defs/#{name}" }
          end
        },
        "Resource" => {
          "type" => "object",
          "required" => %w[name uri],
          "properties" => META_PROPERTY.merge(
            "annotations" => { "$ref" => "#/$defs/Annotations" },
            "description" => { "type" => "string" },
            "icons" => { "type" => "array", "items" => { "$ref" => "#/$defs/Icon" } },
            "mimeType" => { "type" => "string" },
            "name" => { "type" => "string" },
            "size" => { "type" => "integer" },
            "title" => { "type" => "string" },
            "uri" => { "type" => "string", "format" => "uri" }
          )
        },
        "PromptMessage" => {
          "type" => "object",
          "required" => %w[content role],
          "properties" => {
            "content" => { "$ref" => "#/$defs/ContentBlock" },
            "role" => { "type" => "string", "enum" => %w[assistant user] }
          }
        },
        "GetPromptResult" => {
          "type" => "object",
          "required" => [ "messages" ],
          "properties" => META_PROPERTY.merge(
            "description" => { "type" => "string" },
            "messages" => { "type" => "array", "items" => { "$ref" => "#/$defs/PromptMessage" } }
          )
        },
        "CallToolResult" => {
          "type" => "object",
          "required" => [ "content" ],
          "properties" => META_PROPERTY.merge(
            "content" => { "type" => "array", "items" => { "$ref" => "#/$defs/ContentBlock" } },
            "isError" => { "type" => "boolean" },
            "structuredContent" => { "type" => "object" }
          )
        }
      }.freeze

      FORMAT_VALIDATORS = {
        "byte" => lambda do |value, _format|
          Base64.strict_decode64(value)
          true
        rescue ArgumentError
          false
        end,
        "uri" => lambda do |value, _format|
          Addressable::URI.parse(value).absolute?
        rescue Addressable::URI::InvalidURIError, TypeError
          false
        end
      }.freeze

      SCHEMERS = %w[Annotations ContentBlock Resource GetPromptResult CallToolResult].to_h do |name|
        schema = {
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          "$ref" => "#/$defs/#{name}",
          "$defs" => DEFINITIONS
        }
        [ name, JSONSchemer.schema(schema, formats: FORMAT_VALIDATORS) ]
      end.freeze

      module_function

      def validate_annotations!(annotations)
        return if annotations.nil?

        validate!(SCHEMERS.fetch("Annotations"), annotations, "annotations")
      end

      def validate_content_block!(content)
        validate!(SCHEMERS.fetch("ContentBlock"), content, "content")
      end

      def validate_resource!(resource)
        validate!(SCHEMERS.fetch("Resource"), resource, "resource")
      end

      def validate_prompt_result!(result)
        validate!(SCHEMERS.fetch("GetPromptResult"), result, "prompt result")
      end

      def validate_tool_result!(result)
        validate!(SCHEMERS.fetch("CallToolResult"), result, "tool result")
      end

      def copy_object!(value, label)
        source =
          if value.is_a?(Hash)
            value
          elsif value.is_a?(Array)
            nil
          elsif value.respond_to?(:to_hash)
            value.to_hash
          elsif value.respond_to?(:to_h)
            value.to_h
          end

        raise ArgumentError, "#{label} must be a JSON object" unless source.is_a?(Hash)

        source.deep_dup.tap { |copy| ensure_json!(copy, label) }
      end

      def copy_content_block!(content)
        copy = copy_object!(content, "content")
        validate_content_block!(copy)
        copy
      end

      def ensure_json!(value, label)
        JSON.generate(value)
      rescue JSON::GeneratorError, JSON::NestingError => e
        raise ArgumentError, "#{label} must be JSON-serializable: #{e.message}"
      end

      def validate!(schemer, value, label)
        ensure_json!(value, label)
        error = schemer.validate(value).first
        return value unless error

        pointer = error.fetch("data_pointer", "")
        location = pointer.empty? ? "" : " at #{pointer}"
        raise ArgumentError, "#{label} is not valid MCP 2025-11-25 data#{location}: #{error.fetch('error')}"
      end
      private_class_method :validate!
    end
  end
end

# frozen_string_literal: true

require "json_schemer"

module ActionMCP
  module Server
    class SamplingRequest
      UNSET = Object.new.freeze

      TOOL_SCHEMA_OBJECT = {
        "type" => "object",
        "required" => [ "type" ],
        "properties" => {
          "$schema" => { "type" => "string" },
          "properties" => {
            "type" => "object",
            "additionalProperties" => {
              "type" => "object",
              "properties" => {},
              "additionalProperties" => true
            }
          },
          "required" => { "type" => "array", "items" => { "type" => "string" } },
          "type" => { "type" => "string", "const" => "object" }
        }
      }.freeze

      SAMPLING_DEFINITIONS = Content::Validation::DEFINITIONS.merge(
        "ProgressToken" => { "type" => %w[string integer] },
        "Role" => { "type" => "string", "enum" => %w[assistant user] },
        "ToolSchema" => TOOL_SCHEMA_OBJECT,
        "ModelHint" => {
          "type" => "object",
          "properties" => { "name" => { "type" => "string" } }
        },
        "ModelPreferences" => {
          "type" => "object",
          "properties" => {
            "hints" => {
              "type" => "array",
              "items" => Content::Validation.ref("ModelHint")
            },
            "costPriority" => { "type" => "number", "minimum" => 0, "maximum" => 1 },
            "speedPriority" => { "type" => "number", "minimum" => 0, "maximum" => 1 },
            "intelligencePriority" => { "type" => "number", "minimum" => 0, "maximum" => 1 }
          }
        },
        "ToolAnnotations" => {
          "type" => "object",
          "properties" => {
            "destructiveHint" => { "type" => "boolean" },
            "idempotentHint" => { "type" => "boolean" },
            "openWorldHint" => { "type" => "boolean" },
            "readOnlyHint" => { "type" => "boolean" },
            "title" => { "type" => "string" }
          }
        },
        "ToolExecution" => {
          "type" => "object",
          "properties" => {
            "taskSupport" => {
              "type" => "string",
              "enum" => %w[forbidden optional required]
            }
          }
        },
        "Tool" => {
          "type" => "object",
          "required" => %w[inputSchema name],
          "properties" => Content::Validation::META_PROPERTY.merge(
            "annotations" => Content::Validation.ref("ToolAnnotations"),
            "description" => { "type" => "string" },
            "execution" => Content::Validation.ref("ToolExecution"),
            "icons" => { "type" => "array", "items" => Content::Validation.ref("Icon") },
            "inputSchema" => Content::Validation.ref("ToolSchema"),
            "name" => { "type" => "string" },
            "outputSchema" => Content::Validation.ref("ToolSchema"),
            "title" => { "type" => "string" }
          )
        },
        "ToolChoice" => {
          "type" => "object",
          "properties" => {
            "mode" => { "type" => "string", "enum" => %w[auto none required] }
          }
        },
        "TaskMetadata" => {
          "type" => "object",
          "properties" => { "ttl" => { "type" => "integer" } }
        },
        "ToolUseContent" => {
          "type" => "object",
          "required" => %w[id input name type],
          "properties" => Content::Validation::META_PROPERTY.merge(
            "id" => { "type" => "string" },
            "input" => { "type" => "object" },
            "name" => { "type" => "string" },
            "type" => { "type" => "string", "const" => "tool_use" }
          )
        },
        "ToolResultContent" => {
          "type" => "object",
          "required" => %w[content toolUseId type],
          "properties" => Content::Validation::META_PROPERTY.merge(
            "content" => {
              "type" => "array",
              "items" => Content::Validation.ref("ContentBlock")
            },
            "isError" => { "type" => "boolean" },
            "structuredContent" => { "type" => "object" },
            "toolUseId" => { "type" => "string" },
            "type" => { "type" => "string", "const" => "tool_result" }
          )
        },
        "SamplingMessageContentBlock" => {
          "anyOf" => Content::Validation.refs(*%w[TextContent ImageContent AudioContent ToolUseContent ToolResultContent])
        },
        "SamplingMessage" => {
          "type" => "object",
          "required" => %w[content role],
          "properties" => Content::Validation::META_PROPERTY.merge(
            "content" => {
              "anyOf" => [
                Content::Validation.ref("SamplingMessageContentBlock"),
                {
                  "type" => "array",
                  "items" => Content::Validation.ref("SamplingMessageContentBlock")
                }
              ]
            },
            "role" => Content::Validation.ref("Role")
          )
        },
        "CreateMessageRequestParams" => {
          "type" => "object",
          "required" => %w[maxTokens messages],
          "properties" => {
            "_meta" => {
              "type" => "object",
              "properties" => {
                "progressToken" => Content::Validation.ref("ProgressToken")
              }
            },
            "includeContext" => {
              "type" => "string",
              "enum" => %w[allServers none thisServer]
            },
            "maxTokens" => { "type" => "integer" },
            "messages" => {
              "type" => "array",
              "items" => Content::Validation.ref("SamplingMessage")
            },
            "metadata" => { "type" => "object" },
            "modelPreferences" => Content::Validation.ref("ModelPreferences"),
            "stopSequences" => { "type" => "array", "items" => { "type" => "string" } },
            "systemPrompt" => { "type" => "string" },
            "task" => Content::Validation.ref("TaskMetadata"),
            "temperature" => { "type" => "number" },
            "toolChoice" => Content::Validation.ref("ToolChoice"),
            "tools" => { "type" => "array", "items" => Content::Validation.ref("Tool") }
          }
        }
      ).freeze

      PARAMS_SCHEMA = {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "$ref" => "#/$defs/CreateMessageRequestParams",
        "$defs" => SAMPLING_DEFINITIONS
      }.freeze
      PARAMS_SCHEMER = JSONSchemer.schema(
        PARAMS_SCHEMA,
        formats: Content::Validation::FORMAT_VALIDATORS
      )

      class << self
        def configure
          yield self
        end

        def messages(value = UNSET)
          @default_messages = value.map { |message| normalize_message(message) } unless value.equal?(UNSET)
          @default_messages ||= []
        end

        def model_hints(value = UNSET)
          @default_model_hints = value unless value.equal?(UNSET)
          @default_model_hints ||= []
        end

        # Class-level defaults: called with a value to set it, without one to read it.
        { system_prompt: nil, include_context: nil, intelligence_priority: 0.9, max_tokens: 500, temperature: 0.7 }
          .each do |name, fallback|
            define_method(name) do |value = UNSET|
              instance_variable_set(:"@default_#{name}", value) unless value.equal?(UNSET)
              stored = instance_variable_get(:"@default_#{name}")
              stored.nil? ? fallback : stored
            end
          end

        def validate_params!(params)
          raise ArgumentError, "Sampling request params must be an object" unless params.is_a?(Hash)

          wire_params = params.deep_stringify_keys
          errors = PARAMS_SCHEMER.validate(wire_params).to_a
          unless errors.empty?
            pointers = errors.map { |error| error["data_pointer"].presence || "/" }.uniq
            raise ArgumentError, "Sampling request must match MCP 2025-11-25 at #{pointers.join(', ')}"
          end

          validate_tool_conversation!(wire_params.fetch("messages"))
          params
        end

        private

        def validate_tool_conversation!(messages)
          expected_ids = nil
          seen_tool_use_ids = {}

          messages.each_with_index do |message, index|
            blocks = message["content"].is_a?(Array) ? message["content"] : [ message["content"] ]
            tool_results = blocks.select { |block| block["type"] == "tool_result" }

            if expected_ids
              validate_tool_results!(message, blocks, tool_results, expected_ids, index)
              expected_ids = nil
              next
            end

            if tool_results.any?
              validate_tool_result_message!(message, blocks, index)
              invalid_tool_conversation!(index, "tool results do not match a preceding tool use")
            end

            tool_uses = blocks.select { |block| block["type"] == "tool_use" }
            next if tool_uses.empty?

            unless message["role"] == "assistant"
              invalid_tool_conversation!(index, "tool uses must be in an assistant message")
            end

            ids = tool_uses.map { |tool_use| tool_use.fetch("id") }
            reject_duplicate_ids!(ids, index, "tool use")

            if (duplicate = ids.find { |id| seen_tool_use_ids.key?(id) })
              invalid_tool_conversation!(index, "tool use ID #{duplicate.inspect} is not unique")
            end

            ids.each { |id| seen_tool_use_ids[id] = true }
            expected_ids = ids
          end

          return unless expected_ids

          invalid_tool_conversation!(messages.length, "assistant tool uses are missing their next user results")
        end

        def validate_tool_results!(message, blocks, tool_results, expected_ids, index)
          validate_tool_result_message!(message, blocks, index)

          result_ids = tool_results.map { |tool_result| tool_result.fetch("toolUseId") }
          reject_duplicate_ids!(result_ids, index, "tool result")
          return if result_ids.sort == expected_ids.sort

          invalid_tool_conversation!(index, "tool result IDs must exactly match the preceding tool use IDs")
        end

        def validate_tool_result_message!(message, blocks, index)
          valid = message["role"] == "user" && blocks.any? &&
                  blocks.all? { |block| block["type"] == "tool_result" }
          return if valid

          invalid_tool_conversation!(index, "tool result messages must be user messages containing only results")
        end

        def reject_duplicate_ids!(ids, index, label)
          return if ids.uniq.length == ids.length

          invalid_tool_conversation!(index, "#{label} IDs must not contain duplicates")
        end

        def invalid_tool_conversation!(index, reason)
          raise ArgumentError,
                "Sampling request must match MCP 2025-11-25 at /messages/#{index}: #{reason}"
        end

        def normalize_message(message)
          raise ArgumentError, "Sampling messages must be objects" unless message.is_a?(Hash)

          normalized = message.symbolize_keys
          content = normalized[:content]
          if content.respond_to?(:to_h) && !content.is_a?(Hash) && !content.is_a?(Array)
            normalized[:content] = content.to_h
          end
          normalized
        end
      end

      attr_accessor :system_prompt, :model_hints, :cost_priority, :speed_priority,
                    :intelligence_priority, :max_tokens, :temperature, :stop_sequences,
                    :metadata, :tools, :tool_choice, :task, :request_meta
      attr_reader :messages, :context

      def initialize
        @messages = self.class.messages.map(&:deep_dup)
        @system_prompt = self.class.system_prompt
        @context = self.class.include_context
        @model_hints = self.class.model_hints.deep_dup
        @intelligence_priority = self.class.intelligence_priority
        @max_tokens = self.class.max_tokens
        @temperature = self.class.temperature

        yield self if block_given?
      end

      def messages=(value)
        @messages = value.map { |message| self.class.send(:normalize_message, message) }
      end

      def include_context=(value)
        @context = value
      end

      def add_message(content, role: "user", _meta: nil)
        if content.respond_to?(:to_h) && !content.is_a?(Hash) && !content.is_a?(Array)
          content = content.to_h
        end
        content = Content::Text.new(content, annotations: nil).to_h if content.is_a?(String)

        message = { role: role, content: content }
        message[:_meta] = _meta if _meta
        @messages << message
      end

      def to_h
        params = {
          messages: messages.map { |message| message.slice(:role, :content, :_meta).compact },
          systemPrompt: system_prompt,
          includeContext: context,
          modelPreferences: {
            hints: model_hints.map { |hint| hint.is_a?(Hash) ? hint : { name: hint } },
            costPriority: cost_priority,
            speedPriority: speed_priority,
            intelligencePriority: intelligence_priority
          }.compact,
          maxTokens: max_tokens,
          temperature: temperature,
          stopSequences: stop_sequences,
          metadata: metadata,
          tools: tools,
          toolChoice: tool_choice,
          task: task,
          _meta: request_meta
        }.compact

        self.class.validate_params!(params)
      end
    end
  end
end

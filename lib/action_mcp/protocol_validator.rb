# frozen_string_literal: true

require "json_schemer"

module ActionMCP
  # Validates the stable MCP JSON-RPC envelope and client message parameters.
  class ProtocolValidator
    ValidationError = Data.define(:code, :message)

    ID_SCHEMA = { "type" => [ "string", "integer" ] }.freeze
    PROGRESS_TOKEN_SCHEMA = { "type" => [ "string", "integer" ] }.freeze

    REQUEST_META_SCHEMA = {
      "type" => "object",
      "properties" => {
        "progressToken" => PROGRESS_TOKEN_SCHEMA
      },
      "additionalProperties" => true
    }.freeze

    NOTIFICATION_META_SCHEMA = {
      "type" => "object",
      "additionalProperties" => true
    }.freeze

    REQUEST_PARAMS_SCHEMA = {
      "type" => "object",
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA
      },
      "additionalProperties" => true
    }.freeze

    NOTIFICATION_PARAMS_SCHEMA = {
      "type" => "object",
      "properties" => {
        "_meta" => NOTIFICATION_META_SCHEMA
      },
      "additionalProperties" => true
    }.freeze

    PAGINATED_PARAMS_SCHEMA = {
      "type" => "object",
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "cursor" => { "type" => "string" }
      },
      "additionalProperties" => true
    }.freeze

    ICON_SCHEMA = {
      "type" => "object",
      "required" => [ "src" ],
      "properties" => {
        "src" => { "type" => "string", "format" => "uri" },
        "mimeType" => { "type" => "string" },
        "sizes" => {
          "type" => "array",
          "items" => { "type" => "string" }
        },
        "theme" => {
          "type" => "string",
          "enum" => %w[dark light]
        }
      },
      "additionalProperties" => true
    }.freeze

    IMPLEMENTATION_SCHEMA = {
      "type" => "object",
      "required" => %w[name version],
      "properties" => {
        "name" => { "type" => "string" },
        "title" => { "type" => "string" },
        "version" => { "type" => "string" },
        "description" => { "type" => "string" },
        "websiteUrl" => { "type" => "string", "format" => "uri" },
        "icons" => {
          "type" => "array",
          "items" => ICON_SCHEMA
        }
      },
      "additionalProperties" => true
    }.freeze

    EMPTY_CAPABILITY_SCHEMA = {
      "type" => "object",
      "additionalProperties" => true
    }.freeze

    CLIENT_CAPABILITIES_SCHEMA = {
      "type" => "object",
      "properties" => {
        "elicitation" => {
          "type" => "object",
          "properties" => {
            "form" => EMPTY_CAPABILITY_SCHEMA,
            "url" => EMPTY_CAPABILITY_SCHEMA
          },
          "additionalProperties" => true
        },
        "experimental" => {
          "type" => "object",
          "additionalProperties" => EMPTY_CAPABILITY_SCHEMA
        },
        "roots" => {
          "type" => "object",
          "properties" => {
            "listChanged" => { "type" => "boolean" }
          },
          "additionalProperties" => true
        },
        "sampling" => {
          "type" => "object",
          "properties" => {
            "context" => EMPTY_CAPABILITY_SCHEMA,
            "tools" => EMPTY_CAPABILITY_SCHEMA
          },
          "additionalProperties" => true
        },
        "tasks" => {
          "type" => "object",
          "properties" => {
            "cancel" => EMPTY_CAPABILITY_SCHEMA,
            "list" => EMPTY_CAPABILITY_SCHEMA,
            "requests" => {
              "type" => "object",
              "properties" => {
                "elicitation" => {
                  "type" => "object",
                  "properties" => {
                    "create" => EMPTY_CAPABILITY_SCHEMA
                  },
                  "additionalProperties" => true
                },
                "sampling" => {
                  "type" => "object",
                  "properties" => {
                    "createMessage" => EMPTY_CAPABILITY_SCHEMA
                  },
                  "additionalProperties" => true
                }
              },
              "additionalProperties" => true
            }
          },
          "additionalProperties" => true
        }
      },
      "additionalProperties" => true
    }.freeze

    INITIALIZE_PARAMS_SCHEMA = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "type" => "object",
      "required" => %w[protocolVersion capabilities clientInfo],
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "protocolVersion" => { "type" => "string" },
        "capabilities" => CLIENT_CAPABILITIES_SCHEMA,
        "clientInfo" => IMPLEMENTATION_SCHEMA
      },
      "additionalProperties" => true
    }.freeze

    RESOURCE_URI_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => [ "uri" ],
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "uri" => { "type" => "string", "format" => "uri" }
      },
      "additionalProperties" => true
    }.freeze

    GET_PROMPT_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => [ "name" ],
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "name" => { "type" => "string" },
        "arguments" => {
          "type" => "object",
          "additionalProperties" => { "type" => "string" }
        }
      },
      "additionalProperties" => true
    }.freeze

    TASK_METADATA_SCHEMA = {
      "type" => "object",
      "properties" => {
        "ttl" => { "type" => "integer" }
      },
      "additionalProperties" => true
    }.freeze

    CALL_TOOL_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => [ "name" ],
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "name" => { "type" => "string" },
        "arguments" => {
          "type" => "object",
          "additionalProperties" => true
        },
        "task" => TASK_METADATA_SCHEMA
      },
      "additionalProperties" => true
    }.freeze

    TASK_ID_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => [ "taskId" ],
      "properties" => {
        "taskId" => { "type" => "string" }
      },
      "additionalProperties" => true
    }.freeze

    SET_LEVEL_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => [ "level" ],
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "level" => {
          "type" => "string",
          "enum" => %w[alert critical debug emergency error info notice warning]
        }
      },
      "additionalProperties" => true
    }.freeze

    COMPLETE_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => %w[argument ref],
      "properties" => {
        "_meta" => REQUEST_META_SCHEMA,
        "argument" => {
          "type" => "object",
          "required" => %w[name value],
          "properties" => {
            "name" => { "type" => "string" },
            "value" => { "type" => "string" }
          },
          "additionalProperties" => true
        },
        "context" => {
          "type" => "object",
          "properties" => {
            "arguments" => {
              "type" => "object",
              "additionalProperties" => { "type" => "string" }
            }
          },
          "additionalProperties" => true
        },
        "ref" => {
          "anyOf" => [
            {
              "type" => "object",
              "required" => %w[name type],
              "properties" => {
                "name" => { "type" => "string" },
                "title" => { "type" => "string" },
                "type" => { "const" => "ref/prompt" }
              },
              "additionalProperties" => true
            },
            {
              "type" => "object",
              "required" => %w[type uri],
              "properties" => {
                "type" => { "const" => "ref/resource" },
                "uri" => { "type" => "string", "format" => "uri-template" }
              },
              "additionalProperties" => true
            }
          ]
        }
      },
      "additionalProperties" => true
    }.freeze

    CANCELLED_NOTIFICATION_PARAMS_SCHEMA = {
      "type" => "object",
      "properties" => {
        "_meta" => NOTIFICATION_META_SCHEMA,
        "reason" => { "type" => "string" },
        "requestId" => ID_SCHEMA
      },
      "additionalProperties" => true
    }.freeze

    PROGRESS_NOTIFICATION_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => %w[progress progressToken],
      "properties" => {
        "_meta" => NOTIFICATION_META_SCHEMA,
        "message" => { "type" => "string" },
        "progress" => { "type" => "number" },
        "progressToken" => PROGRESS_TOKEN_SCHEMA,
        "total" => { "type" => "number" }
      },
      "additionalProperties" => true
    }.freeze

    TASK_STATUS_NOTIFICATION_PARAMS_SCHEMA = {
      "type" => "object",
      "required" => %w[createdAt lastUpdatedAt status taskId ttl],
      "properties" => {
        "_meta" => NOTIFICATION_META_SCHEMA,
        "createdAt" => { "type" => "string" },
        "lastUpdatedAt" => { "type" => "string" },
        "pollInterval" => { "type" => "integer" },
        "status" => {
          "type" => "string",
          "enum" => %w[cancelled completed failed input_required working]
        },
        "statusMessage" => { "type" => "string" },
        "taskId" => { "type" => "string" },
        "ttl" => { "type" => [ "integer", "null" ] }
      },
      "additionalProperties" => true
    }.freeze

    MESSAGE_SCHEMA = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "anyOf" => [
        {
          "type" => "object",
          "required" => %w[jsonrpc id method],
          "properties" => {
            "jsonrpc" => { "const" => "2.0" },
            "id" => ID_SCHEMA,
            "method" => { "type" => "string" },
            "params" => { "type" => "object", "additionalProperties" => true }
          },
          "additionalProperties" => true
        },
        {
          "type" => "object",
          "required" => %w[jsonrpc method],
          "not" => { "required" => [ "id" ] },
          "properties" => {
            "jsonrpc" => { "const" => "2.0" },
            "method" => { "type" => "string" },
            "params" => { "type" => "object", "additionalProperties" => true }
          },
          "additionalProperties" => true
        },
        {
          "type" => "object",
          "required" => %w[jsonrpc id result],
          "properties" => {
            "jsonrpc" => { "const" => "2.0" },
            "id" => ID_SCHEMA,
            "result" => { "type" => "object", "additionalProperties" => true }
          },
          "additionalProperties" => true
        },
        {
          "type" => "object",
          "required" => %w[jsonrpc error],
          "properties" => {
            "jsonrpc" => { "const" => "2.0" },
            "id" => ID_SCHEMA,
            "error" => {
              "type" => "object",
              "required" => %w[code message],
              "properties" => {
                "code" => { "type" => "integer" },
                "message" => { "type" => "string" },
                "data" => {}
              },
              "additionalProperties" => true
            }
          },
          "additionalProperties" => true
        }
      ]
    }.freeze

    REQUEST_PARAM_SCHEMAS = {
      "initialize" => INITIALIZE_PARAMS_SCHEMA,
      "ping" => REQUEST_PARAMS_SCHEMA,
      "resources/list" => PAGINATED_PARAMS_SCHEMA,
      "resources/templates/list" => PAGINATED_PARAMS_SCHEMA,
      "resources/read" => RESOURCE_URI_PARAMS_SCHEMA,
      "resources/subscribe" => RESOURCE_URI_PARAMS_SCHEMA,
      "resources/unsubscribe" => RESOURCE_URI_PARAMS_SCHEMA,
      "prompts/list" => PAGINATED_PARAMS_SCHEMA,
      "prompts/get" => GET_PROMPT_PARAMS_SCHEMA,
      "tools/list" => PAGINATED_PARAMS_SCHEMA,
      "tools/call" => CALL_TOOL_PARAMS_SCHEMA,
      "tasks/get" => TASK_ID_PARAMS_SCHEMA,
      "tasks/result" => TASK_ID_PARAMS_SCHEMA,
      "tasks/cancel" => TASK_ID_PARAMS_SCHEMA,
      "tasks/list" => PAGINATED_PARAMS_SCHEMA,
      "logging/setLevel" => SET_LEVEL_PARAMS_SCHEMA,
      "completion/complete" => COMPLETE_PARAMS_SCHEMA
    }.freeze

    REQUIRED_REQUEST_PARAMS = %w[
      initialize
      resources/read
      resources/subscribe
      resources/unsubscribe
      prompts/get
      tools/call
      tasks/get
      tasks/result
      tasks/cancel
      logging/setLevel
      completion/complete
    ].freeze

    NOTIFICATION_PARAM_SCHEMAS = {
      "notifications/cancelled" => CANCELLED_NOTIFICATION_PARAMS_SCHEMA,
      "notifications/initialized" => NOTIFICATION_PARAMS_SCHEMA,
      "notifications/progress" => PROGRESS_NOTIFICATION_PARAMS_SCHEMA,
      "notifications/tasks/status" => TASK_STATUS_NOTIFICATION_PARAMS_SCHEMA,
      "notifications/roots/list_changed" => NOTIFICATION_PARAMS_SCHEMA
    }.freeze

    REQUIRED_NOTIFICATION_PARAMS = %w[
      notifications/cancelled
      notifications/progress
      notifications/tasks/status
    ].freeze

    MESSAGE_SCHEMER = JSONSchemer.schema(MESSAGE_SCHEMA)
    REQUEST_PARAM_SCHEMERS = REQUEST_PARAM_SCHEMAS.transform_values { |schema| JSONSchemer.schema(schema) }.freeze
    NOTIFICATION_PARAM_SCHEMERS = NOTIFICATION_PARAM_SCHEMAS.transform_values do |schema|
      JSONSchemer.schema(schema)
    end.freeze

    class << self
      def valid_message?(payload)
        MESSAGE_SCHEMER.valid?(normalize(payload))
      end

      def valid?(payload)
        valid_message?(payload)
      end

      def valid_initialize_params?(params)
        REQUEST_PARAM_SCHEMERS.fetch("initialize").valid?(normalize(params))
      end

      def client_message_validation_error(payload)
        case payload
        when JSON_RPC::Request
          validate_request(payload)
        when JSON_RPC::Notification
          validate_notification(payload)
        end
      end

      def request_params_validation_error(method, params)
        schemer = REQUEST_PARAM_SCHEMERS[method]
        return unless schemer

        validate_params(method, params, schemer, REQUIRED_REQUEST_PARAMS)
      end

      private

      def validate_request(payload)
        request_params_validation_error(payload.method, payload.params)
      end

      def validate_notification(payload)
        schemer = NOTIFICATION_PARAM_SCHEMERS[payload.method]
        unless schemer
          return ValidationError.new(
            code: :method_not_found,
            message: "Unsupported MCP notification method: #{payload.method}"
          )
        end

        validate_params(payload.method, payload.params, schemer, REQUIRED_NOTIFICATION_PARAMS)
      end

      def validate_params(method, params, schemer, required_methods)
        if params.nil?
          return unless required_methods.include?(method)

          return ValidationError.new(code: :invalid_params, message: "Invalid params for #{method}: params are required")
        end

        errors = schemer.validate(normalize(params)).to_a
        return if errors.empty?

        ValidationError.new(
          code: :invalid_params,
          message: "Invalid params for #{method}: #{validation_messages(errors).join(', ')}"
        )
      end

      def validation_messages(errors)
        errors.map do |error|
          error["error"].presence || "#{error['data_pointer'].presence || '/'} (#{error['type']})"
        end.uniq
      end

      def normalize(value)
        value.is_a?(Hash) ? value.deep_stringify_keys : value
      end
    end
  end
end

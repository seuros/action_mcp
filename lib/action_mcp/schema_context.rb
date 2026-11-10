# frozen_string_literal: true

module ActionMCP
  # Receiver for schema keywords given as procs. The proc runs through
  # instance_exec, so it reads the session and the current user the same way
  # a tool does:
  #
  #   property :tool, type: "string", enum: -> { current_user.allowed_tools }
  #   collection :labels, type: "string", enum: -> { session_data["labels"] }
  #
  # session is nil when the schema is built outside a request (rake tasks).
  # A proc that raises surfaces as ActionMCP::SchemaResolutionError.
  class SchemaContext
    include CurrentHelpers

    attr_reader :session

    def initialize(session = nil, owner = nil)
      @session = session
      @owner = owner
    end

    def session_data
      session&.session_data
    end

    def resolve(value)
      case value
      when Hash then value.to_h { |key, nested| [ key, resolve(nested) ] }
      when Array then value.map { |nested| resolve(nested) }
      when Proc then resolve(evaluate(value))
      else value.duplicable? ? value.dup : value
      end
    end

    def evaluate(keyword_proc)
      instance_exec(&keyword_proc)
    rescue StandardError => e
      raise SchemaResolutionError, "Schema keyword proc for #{@owner || 'a tool'} failed: #{e.class}: #{e.message}"
    end

    def self.dynamic?(value)
      case value
      when Hash then value.each_value.any? { |nested| dynamic?(nested) }
      when Array then value.any? { |nested| dynamic?(nested) }
      else value.is_a?(Proc)
      end
    end
  end
end

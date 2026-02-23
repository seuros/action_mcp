# frozen_string_literal: true

module ActionMCP
  # Manages resource resolution results and errors for ResourceTemplate operations.
  # Unlike ToolResponse, ResourceResponse only uses JSON-RPC protocol errors per MCP spec.
  class ResourceResponse < BaseResponse
    attr_reader :contents

    delegate :empty?, :size, :each, :find, :map, to: :contents

    def initialize
      super
      @contents = []
    end

    # Add a resource content item to the response
    def add_content(content)
      @contents << content
      content # Return the content for chaining
    end

    # Add multiple content items
    def add_contents(contents_array)
      @contents.concat(contents_array)
      self
    end

    # Mark as error with ResourceTemplate-specific error types
    def mark_as_template_not_found!(uri)
      mark_as_error!(
        :invalid_params,
        message: "Resource template not found for URI: #{uri}",
        data: { uri: uri, error_type: "TEMPLATE_NOT_FOUND" }
      )
    end

    def mark_as_parameter_validation_failed!(missing_params, uri)
      mark_as_error!(
        :invalid_params,
        message: "Required parameters missing: #{missing_params.join(', ')}",
        data: {
          uri: uri,
          missing_parameters: missing_params,
          error_type: "PARAMETER_VALIDATION_FAILED"
        }
      )
    end

    def mark_as_resolution_failed!(uri, reason = nil)
      message = "Resource resolution failed for URI: #{uri}"
      message += " - #{reason}" if reason

      mark_as_error!(
        :internal_error,
        message: message,
        data: {
          uri: uri,
          reason: reason,
          error_type: "RESOLUTION_FAILED"
        }
      )
    end

    def mark_as_callback_aborted!(uri)
      mark_as_error!(
        :internal_error,
        message: "Resource resolution was aborted by callback chain",
        data: {
          uri: uri,
          error_type: "CALLBACK_ABORTED"
        }
      )
    end

    def mark_as_not_found!(uri)
      @is_error = true
      @symbol = nil
      @error_message = "Resource not found"
      @error_data = { uri: uri }
      self
    end

    # Override to_h to use -32002 for resource not found (consistent with send_resource_read)
    def to_h(_options = nil)
      if @is_error && @symbol.nil?
        { code: -32_002, message: @error_message, data: @error_data }
      elsif @is_error
        JSON_RPC::JsonRpcError.new(@symbol, message: @error_message, data: @error_data).to_h
      else
        build_success_hash
      end
    end

    # Implementation of build_success_hash for ResourceResponse
    def build_success_hash
      {
        contents: @contents.map(&:to_h)
      }
    end

    # Implementation of compare_with_same_class for ResourceResponse
    def compare_with_same_class(other)
      contents == other.contents && is_error == other.is_error
    end

    # Implementation of hash_components for ResourceResponse
    def hash_components
      [ contents, is_error ]
    end

    # Pretty print for better debugging
    def inspect
      if is_error
        "#<#{self.class.name} error: #{@error_message}>"
      else
        "#<#{self.class.name} contents: #{contents.size} items>"
      end
    end
  end
end

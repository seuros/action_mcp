# frozen_string_literal: true

module ActionMCP
  # Registry for managing tools.
  class ToolsRegistry < RegistryBase
    class << self
      # @!method tools
      #   Returns all registered tools.
      #   @return [Hash] A hash of registered tools.
      alias tools items

      # Calls a tool with the given name and arguments.
      #
      # @param tool_name [String] The name of the tool to call.
      # @param arguments [Hash] The arguments to pass to the tool.
      # @param _metadata [Hash] Optional metadata.
      # @return [Hash] A hash containing the tool's response.
      def tool_call(tool_name, arguments, _metadata = {})
        tool_class = find(tool_name)
        tool = tool_class.new(arguments)

        tool.call
      rescue RegistryBase::NotFound
        error_response(:invalid_params, message: "Tool not found: #{tool_name}")
      rescue StandardError => e
        # FIXME, we should maybe not return the error message to the user
        error_response(:invalid_params, message: "Tool execution failed: #{e.message}")
      end

      def item_klass
        Tool
      end

      private

      def error_response(symbol, message: nil, data: nil)
        response = ToolResponse.new
        response.mark_as_error!(symbol, message: message, data: data)
      end
    end
  end
end

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

        return error_response(tool.errors.full_messages) unless tool.valid?

        process_result(tool.call)
      rescue StandardError => e
        error_response([ "Tool execution failed: #{e.message}" ])
      end

      def item_klass
        Tool
      end

      private

      def process_result(result)
        case result
        when Hash
          return result if result[:isError]
          success_response([ result ])
        when String
          success_response([ Content::Text.new(result) ])
        when Array
          success_response(result)
        else
          success_response([ result ])
        end
      end

      def success_response(content)
        { content: content }
      end

      def error_response(messages)
        {
          content: messages.map { |msg| Content::Text.new(msg) },
          isError: true
        }
      end
    end
  end
end

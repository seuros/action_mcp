# frozen_string_literal: true

module ActionMCP
  # Registry for managing tools.
  class ToolsRegistry < RegistryBase
    class << self
      # @!method tools
      #   Returns all registered tools.
      #   @return [Hash] A hash of registered tools.
      alias tools items
      # @!method available_tools
      #   Returns all enabled tools.
      #   @return [Hash] A hash of enabled tools.
      alias available_tools enabled

      # Calls a tool with the given name and arguments.
      #
      # @param tool_name [String] The name of the tool to call.
      # @param arguments [Hash] The arguments to pass to the tool.
      # @param _metadata [Hash] Optional metadata.
      # @return [Hash] A hash containing the tool's response.
      def tool_call(tool_name, arguments, _metadata = {})
        tool = find(tool_name)
        tool = tool.new(arguments)
        tool.validate
        if tool.valid?
          { content: [ tool.call ] }
        else
          {
            content: tool.errors.full_messages.map { |msg| Content::Text.new(msg) },
            isError: true
          }
        end
      end
    end
  end
end

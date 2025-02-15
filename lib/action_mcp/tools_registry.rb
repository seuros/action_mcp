# frozen_string_literal: true

module ActionMCP
  class ToolsRegistry < RegistryBase
    class << self
      alias tools items
      alias available_tools enabled

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

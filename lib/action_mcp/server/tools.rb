# frozen_string_literal: true

module ActionMCP
  module Server
    module Tools
      def send_tools_list(request_id)
        tools = format_registry_items(ToolsRegistry.non_abstract)
        send_jsonrpc_response(request_id, result: { tools: tools })
      end

      def send_tools_call(request_id, tool_name, arguments, _meta = {})
        result = ToolsRegistry.tool_call(tool_name, arguments, _meta)
        if result.is_error
          send_jsonrpc_response(request_id, error: result)
        else
          send_jsonrpc_response(request_id, result:)
        end
      end
    end
  end
end

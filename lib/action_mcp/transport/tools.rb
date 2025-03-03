# app/concerns/action_mcp/transport/tools.rb
module ActionMCP
  module Transport
    module Tools
      def send_tools_list(request_id)
        tools = format_registry_items(ToolsRegistry.all)
        send_jsonrpc_response(request_id, result: { tools: tools })
      end

      def send_tools_call(request_id, tool_name, arguments, _meta = {})
        result = ToolsRegistry.tool_call(tool_name, arguments, _meta)
        send_jsonrpc_response(request_id, result: result)
      rescue RegistryBase::NotFound
        send_jsonrpc_response(request_id, error: JsonRpc::JsonRpcError.new(
          :method_not_found,
          message: "Tool not found: #{tool_name}"
        ).as_json)
      end
    end
  end
end

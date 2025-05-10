# frozen_string_literal: true

module ActionMCP
  module Server
    module Tools
      def send_tools_list(request_id)
        protocol_version = session.protocol_version
        tools = format_registry_items(ToolsRegistry.non_abstract, protocol_version)
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

      private

      def format_registry_items(registry, protocol_version = nil)
        registry.map { |item| item.klass.to_h(protocol_version: protocol_version) }
      end
    end
  end
end

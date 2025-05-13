# frozen_string_literal: true

# lib/action_mcp/server/registry_management.rb
module ActionMCP
  module Server
    module RegistryManagement
      def send_registry_add_tool(request_id, tool_name)
        tool_class = ActionMCP::ToolsRegistry.find(tool_name)

        if tool_class
          session.register_tool(tool_class)
          send_jsonrpc_response(request_id, result: { success: true })
        else
          send_jsonrpc_error(request_id, :invalid_params, "Tool '#{tool_name}' not found")
        end
      rescue ActionMCP::RegistryBase::NotFound
        send_jsonrpc_error(request_id, :invalid_params, "Tool '#{tool_name}' not found")
      end

      def send_registry_remove_tool(request_id, tool_name)
        tool_class = session.available_tools.find { |t| t.tool_name == tool_name }

        if tool_class
          session.unregister_tool(tool_class)
          send_jsonrpc_response(request_id, result: { success: true })
        else
          send_jsonrpc_error(request_id, :invalid_params, "Tool '#{tool_name}' not in session")
        end
      end

      # Similar methods for prompts and resources
    end
  end
end

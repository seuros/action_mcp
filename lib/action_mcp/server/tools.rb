# frozen_string_literal: true

module ActionMCP
  module Server
    module Tools
      def send_tools_list(request_id, params = {})
        protocol_version = session.protocol_version
        # Extract progress token from _meta if provided
        progress_token = params.dig("_meta", "progressToken")

        # Send initial progress notification if token is provided
        if progress_token
          session.send_progress_notification(
            progressToken: progress_token,
            progress: 0,
            message: "Starting tools list retrieval"
          )
        end

        # Use session's registered tools instead of global registry
        tools = session.registered_tools.map { |tool_class|
          tool_class.to_h(protocol_version: protocol_version)
        }

        # Send completion progress notification if token is provided
        if progress_token
          session.send_progress_notification(
            progressToken: progress_token,
            progress: 100,
            message: "Tools list retrieval complete"
          )
        end

        send_jsonrpc_response(request_id, result: { tools: tools })
      end

      def send_tools_call(request_id, tool_name, arguments, _meta = {})
        # Find tool in session's registry
        tool_class = session.registered_tools.find { |t| t.tool_name == tool_name }

        if tool_class
          # Create tool and set execution context
          tool = tool_class.new(arguments)
          tool.with_context({ session: session })

          result = tool.call

          if result.is_error
            send_jsonrpc_response(request_id, error: result)
          else
            send_jsonrpc_response(request_id, result: result)
          end
        else
          send_jsonrpc_error(request_id, :method_not_found, "Tool '#{tool_name}' not available in this session")
        end
      end

      private

      def format_registry_items(registry, protocol_version = nil)
        registry.map { |item| item.klass.to_h(protocol_version: protocol_version) }
      end
    end
  end
end

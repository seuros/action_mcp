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
        registered_tools = session.registered_tools

        tools = registered_tools.map do |tool_class|
          tool_class.to_h(protocol_version: protocol_version)
        end

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
          begin
            # Create tool and set execution context with request info
            tool = tool_class.new(arguments)
            tool.with_context({
              session: session,
              request: {
                params: {
                  name: tool_name,
                  arguments: arguments,
                  _meta: _meta
                }
              }
            })

            # Wrap tool execution with Rails reloader for development
            result = if Rails.env.development?
              # Preserve Current attributes across reloader boundary
              current_user = ActionMCP::Current.user
              current_gateway = ActionMCP::Current.gateway

              Rails.application.reloader.wrap do
                # Restore Current attributes inside reloader
                ActionMCP::Current.user = current_user
                ActionMCP::Current.gateway = current_gateway
                tool.call
              end
            else
              tool.call
            end

            if result.is_error
              # Convert ToolResponse error to proper JSON-RPC error format
              # Pass the error hash directly - the Response class will handle it
              error_hash = result.to_h
              send_jsonrpc_response(request_id, error: error_hash)
            else
              send_jsonrpc_response(request_id, result: result)
            end
          rescue ArgumentError => e
            # Handle parameter validation errors
            send_jsonrpc_error(request_id, :invalid_params, e.message)
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

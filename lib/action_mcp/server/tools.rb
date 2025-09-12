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
          send_progress_notification(
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
          send_progress_notification(
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

        unless tool_class
          Rails.logger.error "Tool not found: #{tool_name}. Registered tools: #{session.registered_tools.map(&:tool_name).join(', ')}"
          send_jsonrpc_error(request_id, :method_not_found,
                             "Tool '#{tool_name}' not found or not registered for this session")
          return
        end

        # Check if tool requires consent and if consent is granted
        if tool_class.respond_to?(:requires_consent?) && tool_class.requires_consent? && !session.consent_granted_for?(tool_name)
          # Use custom error response for consent required (-32002)
          error = {
            code: -32_002,
            message: "Consent required for tool '#{tool_name}'"
          }
          send_jsonrpc_response(request_id, error: error)
          return
        end

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
            # Protocol error
            send_jsonrpc_response(request_id, error: result.to_h)
          else
            # Success OR tool execution error - both are valid JSON-RPC responses
            send_jsonrpc_response(request_id, result: result.to_h)
          end
        rescue ArgumentError => e
          # Handle parameter validation errors
          send_jsonrpc_error(request_id, :invalid_params, e.message)
        rescue StandardError => e
          # Log the actual error for debugging
          Rails.logger.error "Tool execution error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          send_jsonrpc_error(request_id, :internal_error, "An unexpected error occurred.")
        end
      end

      private

      def format_registry_items(registry, protocol_version = nil)
        registry.map { |item| item.klass.to_h(protocol_version: protocol_version) }
      end
    end
  end
end

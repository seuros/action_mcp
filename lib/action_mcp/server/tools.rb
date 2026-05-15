# frozen_string_literal: true

module ActionMCP
  module Server
    module Tools
      def send_tools_list(request_id, params = {})
        protocol_version = session.protocol_version
        progress_token = params.dig("_meta", "progressToken")

        if progress_token
          send_progress_notification(progressToken: progress_token, progress: 0, message: "Starting tools list retrieval")
        end

        page, next_cursor = paginate(session.registered_tools, cursor: params["cursor"])

        result = { tools: page.map { |t| t.to_h(protocol_version: protocol_version) } }
        result[:nextCursor] = next_cursor if next_cursor

        if progress_token
          send_progress_notification(progressToken: progress_token, progress: 100, message: "Tools list retrieval complete")
        end

        send_jsonrpc_response(request_id, result: result)
      rescue Server::CursorError => e
        send_jsonrpc_error(request_id, :invalid_params, e.message)
      end

      def send_tools_call(request_id, tool_name, arguments, _meta = {}, task_params = nil)
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

        task_support = tool_task_support(tool_class)
        task_requested = !task_params.nil?

        if task_requested && !tasks_enabled?
          send_jsonrpc_error(request_id, :method_not_found,
                             "Task-augmented execution is not available for this session")
          return
        end

        if task_requested
          unless task_params.respond_to?(:to_h)
            send_jsonrpc_error(request_id, :invalid_params, "Task parameters must be an object")
            return
          end

          task_params = task_params.to_h

          if task_support == :forbidden
            send_jsonrpc_error(request_id, :method_not_found,
                               "Tool '#{tool_name}' does not support task-augmented execution")
            return
          end

          handle_task_augmented_tool_call(request_id, tool_name, arguments, _meta, task_params)
          return
        end

        if !task_requested && task_support == :required
          send_jsonrpc_error(request_id, :method_not_found,
                             "Tool '#{tool_name}' requires task-augmented execution")
          return
        end

        # Standard synchronous execution
        execute_tool_synchronously(request_id, tool_class, tool_name, arguments, _meta)
      end

      private

      def execute_tool_synchronously(request_id, tool_class, tool_name, arguments, _meta)
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

      # Handle task-augmented tool calls per MCP 2025-11-25 specification
      # Creates a Task record and executes the tool asynchronously
      def handle_task_augmented_tool_call(request_id, tool_name, arguments, _meta, task_params)
        # Extract task configuration
        ttl = task_params["ttl"] || task_params[:ttl] || 60_000

        # Create task record
        task = session.tasks.create!(
          request_method: "tools/call",
          request_name: tool_name,
          request_params: {
            name: tool_name,
            arguments: arguments,
            task: task_params,
            _meta: _meta
          },
          ttl: ttl
        )
        request_meta = task.request_meta_with_related_task(_meta)
        task.update!(
          request_params: {
            name: tool_name,
            arguments: arguments,
            task: task_params,
            _meta: request_meta
          }
        )

        # Return CreateTaskResult immediately
        send_jsonrpc_response(request_id, result: task.to_create_task_result)

        # Execute tool asynchronously via ActiveJob
        ToolExecutionJob.perform_later(task.id, tool_name, arguments, request_meta)
      rescue StandardError => e
        Rails.logger.error "Failed to create task: #{e.class} - #{e.message}"
        send_jsonrpc_error(request_id, :internal_error, "Failed to create task")
      end

      def tasks_enabled?
        ActionMCP.configuration.tasks_enabled && session.protocol_version == "2025-11-25"
      end

      def tool_task_support(tool_class)
        return :forbidden unless tool_class.respond_to?(:task_support)

        (tool_class.task_support || :forbidden).to_sym
      end

      def format_registry_items(registry, protocol_version = nil)
        registry.map { |item| item.klass.to_h(protocol_version: protocol_version) }
      end
    end
  end
end

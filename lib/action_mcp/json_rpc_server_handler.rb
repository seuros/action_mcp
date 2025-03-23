# frozen_string_literal: true

module ActionMCP
  class JsonRpcServerHandler < JsonRpcHandler
    protected

    # Handle server-specific methods
    # @param rpc_method [String]
    # @param id [String, Integer]
    # @param params [Hash]
    def handle_method(rpc_method, id, params)
      case rpc_method
      when "initialize"                # [SERVER] Client initializing the connection
        transport.send_capabilities(id, params)
      when %r{^prompts/}               # Prompt-related requests
        process_prompts(rpc_method, id, params)
      when %r{^resources/}             # Resource-related requests
        process_resources(rpc_method, id, params)
      when %r{^tools/}                 # Tool-related requests
        process_tools(rpc_method, id, params)
      when "completion/complete"       # Completion requests
        process_completion_complete(id, params)
      else
        puts "\e[31mUnknown client method: #{rpc_method}\e[0m"
      end
    end

    # Server methods (client → server)

    # @param id [String]
    # @param params [Hash]
    # @example {
    #     "ref": {
    #       "type": "ref/prompt",
    #       "name": "code_review"
    #     },
    #     "argument": {
    #       "name": "language",
    #       "value": "py"
    #     }
    #   }
    # @return [Hash]
    # @example {
    #     "completion": {
    #       "values": ["python", "pytorch", "pyside"],
    #       "total": 10,
    #       "hasMore": true
    #     }
    #   }
    def process_completion_complete(id, params)
      # TODO: Not Implemented, but to remove the error message in the inspector
      transport.send_jsonrpc_response(id, result: { completion: { values: [], total: 0, hasMore: false } })
      case params["ref"]["type"]
      when "ref/prompt"
        # TODO: Implement completion
      when "ref/resource"
        # TODO: Implement completion
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_prompts(rpc_method, id, params)
      case rpc_method
      when "prompts/get"              # Get specific prompt
        transport.send_prompts_get(id, params["name"], params["arguments"])
      when "prompts/list"             # List available prompts
        transport.send_prompts_list(id)
      else
        Rails.logger.warn("Unknown prompts method: #{rpc_method}")
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_tools(rpc_method, id, params)
      case rpc_method
      when "tools/list"               # List available tools
        transport.send_tools_list(id)
      when "tools/call"               # Call a tool
        transport.send_tools_call(id, params["name"], params["arguments"])
      else
        Rails.logger.warn("Unknown tools method: #{rpc_method}")
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_resources(rpc_method, id, params)
      case rpc_method
      when "resources/list"           # List available resources
        transport.send_resources_list(id)
      when "resources/templates/list" # List resource templates
        transport.send_resource_templates_list(id)
      when "resources/read"           # Read resource content
        transport.send_resource_read(id, params)
      when "resources/subscribe"      # Subscribe to resource updates
        transport.send_resource_subscribe(id, params["uri"])
      when "resources/unsubscribe"    # Unsubscribe from resource updates
        transport.send_resource_unsubscribe(id, params["uri"])
      else
        Rails.logger.warn("Unknown resources method: #{rpc_method}")
      end
    end

    def process_notifications(rpc_method, params)
      case rpc_method
      when "notifications/initialized" # Client initialization complete
        puts "\e[31mInitialized\e[0m"
        transport.initialize!
      else
        super
      end
    end
  end
end

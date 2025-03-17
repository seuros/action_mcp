# frozen_string_literal: true

module ActionMCP
  # Handler for server-side requests (client -> server)
  class ServerJsonRpcHandler < BaseJsonRpcHandler
    def handle_initialize(id, params)
      # Server-specific initialization
      transport.send_capabilities(id, params)
    end

    def handle_specific_method(rpc_method, id, params)
      case rpc_method
      when %r{^prompts/}               # [SERVER] Prompt-related requests
        process_prompts(rpc_method, id, params)
      when %r{^resources/}             # [SERVER] Resource-related requests
        process_resources(rpc_method, id, params)
      when %r{^tools/}                 # [SERVER] Tool-related requests
        process_tools(rpc_method, id, params)
      when "completion/complete" # [SERVER] Completion requests
        process_completion_complete(id, params)
      else
        Rails.logger.warn("Unknown server method: #{rpc_method}")
      end
    end
    def handle_specific_notification(rpc_method, _params)
      # Server-specific notifications would go here
      case rpc_method
      when "notifications/initialized"            # [SERVER] Initialization complete
        puts "Initialized"
        transport.initialize!
      else
        Rails.logger.warn("Unknown server notification: #{rpc_method}")
      end
    end

    private

    # All the server-specific methods below...

    def process_completion_complete(id, params)
      # Implementation as in original code
      transport.send_jsonrpc_response(id, result: { completion: { values: [], total: 0, hasMore: false } })
      case params["ref"]["type"]
      when "ref/prompt"
        # TODO: Implement completion
      when "ref/resource"
        # TODO: Implement completion
      end
    end

    def process_prompts(rpc_method, id, params)
      case rpc_method
      when "prompts/get"              # [SERVER] Get specific prompt
        transport.send_prompts_get(id, params["name"], params["arguments"])
      when "prompts/list"             # [SERVER] List available prompts
        transport.send_prompts_list(id)
      else
        Rails.logger.warn("Unknown prompts method: #{rpc_method}")
      end
    end

    def process_resources(rpc_method, id, params)
      case rpc_method
      when "resources/list"           # [SERVER] List available resources
        transport.send_resources_list(id)
      when "resources/templates/list" # [SERVER] List resource templates
        transport.send_resource_templates_list(id)
      when "resources/read"           # [SERVER] Read resource content
        transport.send_resource_read(id, params)
      when "resources/subscribe"      # [SERVER] Subscribe to resource updates
        transport.send_resource_subscribe(id, params["uri"])
      when "resources/unsubscribe"    # [SERVER] Unsubscribe from resource updates
        transport.send_resource_unsubscribe(id, params["uri"])
      else
        Rails.logger.warn("Unknown resources method: #{rpc_method}")
      end
    end

    def process_tools(rpc_method, id, params)
      case rpc_method
      when "tools/list"               # [SERVER] List available tools
        transport.send_tools_list(id)
      when "tools/call"               # [SERVER] Call a tool
        transport.send_tools_call(id, params&.dig("name"), params&.dig("arguments"))
      else
        Rails.logger.warn("Unknown tools method: #{rpc_method}")
      end
    end
  end
end

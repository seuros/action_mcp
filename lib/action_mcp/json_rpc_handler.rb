# frozen_string_literal: true

module ActionMCP
  class JsonRpcHandler
    delegate :initialize!, :initialized?, to: :transport
    delegate :write, :read, to: :transport
    attr_reader :transport

    # @param transport [ActionMCP::TransportHandler]
    def initialize(transport)
      @transport = transport
    end

    # Process a single line of input.
    # @param line [String, Hash]
    def call(line)
      request = if line.is_a?(String)
                  line.strip!
                  return if line.empty?

                  begin
                    MultiJson.load(line)
                  rescue MultiJson::ParseError => e
                    Rails.logger.error("Failed to parse JSON: #{e.message}")
                    return
                  end
      else
                  line
      end
      process_request(request)
    end

    private

    # @param request [Hash]
    def process_request(request)
      unless request["jsonrpc"] == "2.0"
        puts "Invalid request: #{request}"
        return
      end
      read(request)
      return if request["error"]
      return if request["result"] == {} # Probably a pong

      rpc_method = request["method"]
      id = request["id"]
      params = request["params"]

      # Common methods (both directions)
      case rpc_method
      when "initialize"                # [SERVER] Client initializing the connection
        transport.send_capabilities(id, params)
      when "ping"                      # [BOTH] Client ping
        transport.send_pong(id)

        # Methods that servers must implement (client → server)
      when %r{^prompts/}               # [SERVER] Prompt-related requests
        process_prompts(rpc_method, id, params)
      when %r{^resources/}             # [SERVER] Resource-related requests
        process_resources(rpc_method, id, params)
      when %r{^tools/}                 # [SERVER] Tool-related requests
        process_tools(rpc_method, id, params)
      when "completion/complete" # [SERVER] Completion requests
        process_completion_complete(id, params)

        # Methods that clients must implement (server → client)
      when "client/setLoggingLevel" # [CLIENT] Server configuring client logging
        process_client_logging(id, params)
      when %r{^roots/}                 # [CLIENT] Roots management
        process_roots(rpc_method, id, params)
      when %r{^sampling/}              # [CLIENT] Sampling requests
        process_sampling(rpc_method, id, params)

        # Notifications (can go both ways)
      when %r{^notifications/}
        puts "\e[31mProcessing notifications\e[0m"
        process_notifications(rpc_method, params)
      else
        puts "\e[31mUnknown method: #{rpc_method} #{request}\e[0m"
      end
    end

    # @param rpc_method [String]
    def process_notifications(rpc_method, params)
      case rpc_method
      when "notifications/initialized"            # [SERVER] Client initialization complete
        puts "\e[31mInitialized\e[0m"
        transport.initialize!
      when "notifications/cancelled"              # [BOTH] Request cancellation
        puts "\e[31m Request #{params['requestId']} cancelled: #{params['reason']}\e[0m"
        # we don't need to do anything here
      when "notifications/resources/updated" # [CLIENT] Resource update notification
        puts "\e[31m Resource #{params['uri']} was updated\e[0m"
        # Handle resource update notification
      when "notifications/tools/list_changed" # [CLIENT] Tool list change notification
        puts "\e[31m Tool list has changed\e[0m"
        # Handle tool list change notification
      when "notifications/prompts/list_changed" # [CLIENT] Prompt list change notification
        puts "\e[31m Prompt list has changed\e[0m"
        # Handle prompt list change notification
      when "notifications/resources/list_changed" # [CLIENT] Resource list change notification
        puts "\e[31m Resource list has changed\e[0m"
        # Handle resource list change notification
      else
        Rails.logger.warn("Unknown notifications method: #{rpc_method}")
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
      when "prompts/get"              # [SERVER] Get specific prompt
        transport.send_prompts_get(id, params["name"], params["arguments"])
      when "prompts/list"             # [SERVER] List available prompts
        transport.send_prompts_list(id)
      else
        Rails.logger.warn("Unknown prompts method: #{rpc_method}")
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
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

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
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

    # Client methods (server → client)

    # @param id [String]
    # @param params [Hash]
    def process_client_logging(id, params)
      level = params["level"]
      transport.set_client_logging_level(id, level)
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_roots(rpc_method, id, params)
      case rpc_method
      when "roots/list"               # [CLIENT] List available roots
        transport.send_roots_list(id)
      when "roots/add"                # [CLIENT] Add a root
        transport.send_roots_add(id, params["uri"], params["name"])
      when "roots/remove"             # [CLIENT] Remove a root
        transport.send_roots_remove(id, params["uri"])
      else
        Rails.logger.warn("Unknown roots method: #{rpc_method}")
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_sampling(rpc_method, id, params)
      case rpc_method
      when "sampling/createMessage" # [CLIENT] Create a message using AI
        # @param id [String]
        # @param params [SamplingRequest]
        transport.send_sampling_create_message(id, params)
      else
        Rails.logger.warn("Unknown sampling method: #{rpc_method}")
      end
    end
  end
end

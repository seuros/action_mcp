# frozen_string_literal: true

module ActionMCP
  module Server
    class JsonRpcHandler < JsonRpcHandlerBase
      # Handle server-specific methods
      # @param rpc_method [String]
      # @param id [String, Integer]
      # @param params [Hash]
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

        # Store the request ID for error responses
        @current_request_id = request["id"] if request.is_a?(Hash)

        process_request(request)
      end

      def handle_method(rpc_method, id, params)
        # Ensure we have the current request ID
        @current_request_id = id

        case rpc_method
        when "initialize"
          transport.send_capabilities(id, params)
        when %r{^prompts/}
          process_prompts(rpc_method, id, params)
        when %r{^resources/}
          process_resources(rpc_method, id, params)
        when %r{^tools/}
          process_tools(rpc_method, id, params)
        when "completion/complete"
          process_completion_complete(id, params)
        else
          transport.send_jsonrpc_error(id, :method_not_found, "Method not found #{rpc_method}")
        end
      rescue StandardError => e
        Rails.logger.error("Error handling method #{rpc_method}: #{e.message}")
        transport.send_jsonrpc_error(id, :internal_error, "Internal error: #{e.message}")
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
        when "prompts/get" # Get specific prompt
          transport.send_prompts_get(id, params["name"], params["arguments"])
        when "prompts/list" # List available prompts
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
        when "tools/list" # List available tools
          transport.send_tools_list(id, params)
        when "tools/call" # Call a tool
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
        when "resources/list" # List available resources
          transport.send_resources_list(id)
        when "resources/templates/list" # List resource templates
          transport.send_resource_templates_list(id)
        when "resources/read" # Read resource content
          transport.send_resource_read(id, params)
        when "resources/subscribe" # Subscribe to resource updates
          transport.send_resource_subscribe(id, params["uri"])
        when "resources/unsubscribe" # Unsubscribe from resource updates
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
end

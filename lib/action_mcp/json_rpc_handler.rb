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

      method = request["method"]
      id = request["id"]
      params = request["params"]

      case method
      when "initialize"
        puts "\e[31mSending capabilities\e[0m"
        transport.send_capabilities(id, params)
      when "ping"
        transport.send_pong(id)
      when /^notifications\//
        puts "\e[31mProcessing notifications\e[0m"
        process_notifications(method)
      when /^prompts\//
        process_prompts(method, id, params)
      when /^resources\//
        process_resources(method, id, params)
      when /^tools\//
        process_tools(method, id, params)
      when "completion/complete"
        process_completion_complete(id, params)
      else
        puts "\e[31mUnknown method: #{method} #{request}\e[0m"
      end
    end

    # @param rpc_method [String]
    def process_notifications(rpc_method)
      case rpc_method
      when "notifications/initialized"
        puts "\e[31mInitialized\e[0m"
        transport.initialize!
      else
        Rails.logger.warn("Unknown notifications method: #{rpc_method}")
      end
    end

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
      when "prompts/get"
        transport.send_prompts_get(id, params["name"], params["arguments"])
      when "prompts/list"
        transport.send_prompts_list(id)
      else
        Rails.logger.warn("Unknown prompts method: #{rpc_method}")
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    # Not implemented
    def process_resources(rpc_method, id, params)
      case rpc_method
      when "resources/list"
        transport.send_resources_list(id)
      when "resources/templates/list"
        transport.send_resource_templates_list(id)
      when "resources/read"
        transport.send_resource_read(id, params)
      else
        Rails.logger.warn("Unknown resources method: #{rpc_method}")
      end
    end

    def process_tools(rpc_method, id, params)
      case rpc_method
      when "tools/list"
        transport.send_tools_list(id)
      when "tools/call"
        transport.send_tools_call(id, params&.dig("name"), params&.dig("arguments"))
      else
        Rails.logger.warn("Unknown tools method: #{rpc_method}")
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class JsonRpcHandler
    attr_reader :transport

    def initialize(transport)
      @transport = transport
    end

    # Process a single line of input.
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

    def process_request(request)
       unless request["jsonrpc"] == "2.0"
         puts "Invalid request: #{request}"
         return
       end
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
        process_notifications(method, id, params)
      when /^prompts\//
        process_prompts(method, id, params)
      when /^resources\//
        process_resources(method, id, params)
      when /^tools\//
        process_tools(method, id, params)
      else
        puts "\e[31mUnknown method: #{method}\e[0m"
        Rails.logger.warn("Unknown method: #{method}")
      end
    end

    def process_notifications(method, _id, _params)
      case method
      when "notifications/initialized"
        puts "\e[31mInitialized\e[0m"
        transport.initialized!
      else
        Rails.logger.warn("Unknown notifications method: #{method}")
      end
    end

    def process_prompts(method, id, params)
      case method
      when "prompts/get"
        transport.send_prompts_get(id, params&.dig("name"), params&.dig("arguments"))
      when "prompts/list"
        transport.send_prompts_list(id)
      else
        Rails.logger.warn("Unknown prompts method: #{method}")
      end
    end

    def process_resources(method, id, params)
      case method
      when "resources/list"
        transport.send_resources_list(id)
      when "resources/templates/list"
        transport.send_resource_templates_list(id)
      when "resources/read"
        transport.send_resource_read(id, params)
      else
        Rails.logger.warn("Unknown resources method: #{method}")
      end
    end

    def process_tools(method, id, params)
      case method
      when "tools/list"
        transport.send_tools_list(id)
      when "tools/call"
        transport.send_tools_call(id, params&.dig("name"), params&.dig("arguments"))
      else
        Rails.logger.warn("Unknown tools method: #{method}")
      end
    end
  end
end

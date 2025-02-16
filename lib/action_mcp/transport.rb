# frozen_string_literal: true

require "action_mcp/logging"
require "securerandom"
require "timeout"

module ActionMCP
  # Handles communication with the client.
  class Transport
    include Logging

    HEARTBEAT_INTERVAL = 15 # seconds
    attr_reader :initialized

    # Initializes a new Transport.
    #
    # @param output_io [IO] An IO-like object where events will be written.
    def initialize(output_io)
      # output_io can be any IO-like object where we write events.
      @output = output_io
      @output.sync = true
      @initialized = false
      @client_capabilities = {}
      @client_info = {}
      @protocol_version = ""
    end

    # Sends the capabilities JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param params [Hash] The parameters including the 'protocolVersion' and 'clientInfo'.
    def send_capabilities(request_id, params = {})
      @protocol_version = params["protocolVersion"]
      @client_info = params["clientInfo"]
      @client_capabilities = params["capabilities"]
      Transport.logger.debug("Client capabilities stored: #{@client_capabilities}")
      capabilities = ActionMCP.configuration.capabilities

      payload = {
        protocolVersion: "2024-11-05",
        serverInfo: {
          name: ActionMCP.configuration.name,
          version: ActionMCP.configuration.version
        }
      }.merge(capabilities)
      send_jsonrpc_response(request_id, result: payload)
    end

    # Marks the transport as initialized.
    #
    # @return [void]
    def initialized!
      @initialized = true
      ActionMCP.logger.debug("Transport initialized.")
    end

    # Sends the resources list JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_resources_list(request_id)
      resources = ResourcesBank.all_resources # fetch all resources
      result_data = { "resources" => resources }
      send_jsonrpc_response(request_id, result: result_data)
      ActionMCP.logger.debug("resources/list: Returned #{resources.size} resources.")
    rescue StandardError => e
      ActionMCP.logger.error("resources/list failed: #{e.message}")
      error_obj = JsonRpc::JsonRpcError.new(
        :internal_error,
        message: "Failed to list resources: #{e.message}"
      ).as_json
      send_jsonrpc_response(request_id, error: error_obj)
    end

    # Sends the resource templates list JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_resource_templates_list(request_id)
      templates = ResourcesBank.all_templates # get all resource templates
      result_data = { "resourceTemplates" => templates }
      send_jsonrpc_response(request_id, result: result_data)
      ActionMCP.logger.debug("resources/templates/list: Returned #{templates.size} resource templates.")
    rescue StandardError => e
      ActionMCP.logger.error("resources/templates/list failed: #{e.message}")
      error_obj = JsonRpc::JsonRpcError.new(
        :internal_error,
        message: "Failed to list resource templates: #{e.message}"
      ).as_json
      send_jsonrpc_response(request_id, error: error_obj)
    end

    # Sends the resource read JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param params [Hash] The parameters including the 'uri' for the resource.
    def send_resource_read(request_id, params)
      uri = params&.fetch("uri", nil)
      if uri.nil? || uri.empty?
        ActionMCP.logger.error("resources/read: 'uri' parameter is missing")
        error_obj = JsonRpc::JsonRpcError.new(
          :invalid_params,
          message: "Missing 'uri' parameter for resources/read"
        ).as_json
        return send_jsonrpc_response(request_id, error: error_obj)
      end

      begin
        content = ResourcesBank.read(uri) # Expecting an instance of an ActionMCP::Content subclass
        if content.nil?
          ActionMCP.logger.error("resources/read: Resource not found for URI #{uri}")
          error_obj = JsonRpc::JsonRpcError.new(
            :invalid_params,
            message: "Resource not found: #{uri}"
          ).as_json
          return send_jsonrpc_response(request_id, error: error_obj)
        end

        # Use the content object's `to_h` to build the JSON-RPC result.
        result_data = { "contents" => [ content.to_h ] }
        send_jsonrpc_response(request_id, result: result_data)

        log_msg = "resources/read: Successfully read content of #{uri}"
        log_msg += " (#{content.text.size} bytes)" if content.respond_to?(:text) && content.text
        ActionMCP.logger.debug(log_msg)
      rescue StandardError => e
        ActionMCP.logger.error("resources/read: Error reading #{uri} - #{e.message}")
        error_obj = JsonRpc::JsonRpcError.new(
          :internal_error,
          message: "Failed to read resource '#{uri}': #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end

    # Sends the tools list JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_tools_list(request_id)
      tools = format_registry_items(ToolsRegistry.available_tools)
      send_jsonrpc_response(request_id, result: { tools: tools })
    end

    # Sends a call to a tool.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param tool_name [String] The name of the tool.
    # @param arguments [Hash] The arguments for the tool.
    # @param _meta [Hash] Additional metadata.
    def send_tools_call(request_id, tool_name, arguments, _meta = {})
      result = ToolsRegistry.tool_call(tool_name, arguments, _meta)
      send_jsonrpc_response(request_id, result:)
    rescue RegistryBase::NotFound
      send_jsonrpc_response(request_id, error: JsonRpc::JsonRpcError.new(:method_not_found,
                                                                         message: "Tool not found: #{tool_name}").as_json)
    end

    # Sends the prompts list JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_prompts_list(request_id)
      prompts = format_registry_items(PromptsRegistry.available_prompts)
      send_jsonrpc_response(request_id, result: { prompts: prompts })
    end

    # Sends a call to a prompt.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param prompt_name [String] The name of the prompt.
    # @param params [Hash] The parameters for the prompt.
    def send_prompts_get(request_id, prompt_name, params)
      send_jsonrpc_response(request_id, result: PromptsRegistry.prompt_call(prompt_name.to_s, params))
    rescue RegistryBase::NotFound
      send_jsonrpc_response(request_id, error: JsonRpc::JsonRpcError.new(:method_not_found,
                                                                         message: "Prompt not found: #{prompt_name}").as_json)
    end

    # Sends the roots list JSON-RPC request.
    # TODO: test it
    def send_roots_list
      send_jsonrpc_request("roots/list")
    end

    # Sends a JSON-RPC pong response.
    # We don't actually to send any data back because the spec are not fun anymore.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_pong(request_id)
      send_jsonrpc_response(request_id, result: {})
    end

    # Sends a JSON-RPC ping request.
    def send_ping
      send_jsonrpc_request("ping")
    end

    # Sends a JSON-RPC request.
    # @param method [String] The JSON-RPC method.
    # @param params [Hash] The parameters for the method.
    # @param id [String] The request identifier.
    def send_jsonrpc_request(method, params: nil, id: SecureRandom.uuid_v7)
      request = JsonRpc::Request.new(id: id, method: method, params: params)
      write_message(request.to_json)
    end

    # Sends a JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param result [Object] The result data.
    # @param error [Object, nil] The error data, if any.
    def send_jsonrpc_response(request_id, result: nil, error: nil)
      response = JsonRpc::Response.new(id: request_id, result: result, error: error)
      write_message(response.to_json)
    end

    # Sends a generic JSON-RPC notification (no response expected).
    #
    # @param method [String] The JSON-RPC method.
    # @param params [Hash] The parameters for the method.
    def send_jsonrpc_notification(method, params = nil)
      notification = JsonRpc::Notification.new(method: method, params: params)
      write_message(notification.to_json)
    end

    ActiveSupport.run_load_hooks(:action_mcp, self)

    private

    # Formats registry items to a hash representation.
    #
    # @param registry [Hash] The registry containing tool or prompt definitions.
    # @return [Array<Hash>] The formatted registry items.
    def format_registry_items(registry)
      registry.map { |item| item.klass.to_h }
    end

    # Writes a message to the output IO.
    #
    # @param data [String] The data to write.
    def write_message(data)
      Timeout.timeout(5) do # 5 second timeout
        @output.write("#{data}\n")
      end
    rescue Timeout::Error
      ActionMCP.logger.error("Write operation timed out")
      # Handle timeout appropriately
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class Transport
    HEARTBEAT_INTERVAL = 15 # seconds

    def initialize(output_io)
      # output_io can be any IO-like object where we write events.
      @output = output_io
      @output.sync = true
    end

    # Sends the capabilities JSON-RPC notification.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_capabilities(request_id)
      payload = {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: { listChanged: true },
          prompts: { listChanged: true },
          resources: { listChanged: true },
          logging: {}
        },
        serverInfo: {
          name: Rails.application.name,
          version: Rails.application.version.to_s
        }
      }
      send_jsonrpc_response(request_id, result: payload)
    end

    # Sends the tools list JSON-RPC notification.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_tools_list(request_id)
      tools = format_registry_items(ActionMCP::ToolsRegistry.available_tools)
      send_jsonrpc_response(request_id, result: { tools: tools })
    end

    # Sends the resources list JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_resources_list(request_id)
      begin
        resources = ActionMCP::ResourcesRegistry.all_resources  # fetch all resources
        result_data = { "resources" => resources }
        send_jsonrpc_response(request_id, result: result_data)
        Rails.logger.info("resources/list: Returned #{resources.size} resources.")
      rescue StandardError => e
        Rails.logger.error("resources/list failed: #{e.message}")
        error_obj = JsonRpcError.new(
          :internal_error,
          message: "Failed to list resources: #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end

    # Sends the resource templates list JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_resource_templates_list(request_id)
      begin
        templates = ActionMCP::ResourcesRegistry.all_templates  # get all resource templates
        result_data = { "resourceTemplates" => templates }
        send_jsonrpc_response(request_id, result: result_data)
        Rails.logger.info("resources/templates/list: Returned #{templates.size} resource templates.")
      rescue StandardError => e
        Rails.logger.error("resources/templates/list failed: #{e.message}")
        error_obj = JsonRpcError.new(
          :internal_error,
          message: "Failed to list resource templates: #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end

    # Sends the resource read JSON-RPC response.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param params [Hash] The parameters including the 'uri' for the resource.
    def send_resource_read(request_id, params)
      uri = params&.fetch("uri", nil)
      if uri.nil? || uri.empty?
        Rails.logger.error("resources/read: 'uri' parameter is missing")
        error_obj = JsonRpcError.new(
          :invalid_params,
          message: "Missing 'uri' parameter for resources/read"
        ).as_json
        return send_jsonrpc_response(request_id, error: error_obj)
      end

      begin
        content = ActionMCP::ResourcesRegistry.read(uri)  # Expecting an instance of an ActionMCP::Content subclass
        if content.nil?
          Rails.logger.error("resources/read: Resource not found for URI #{uri}")
          error_obj = JsonRpcError.new(
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
        Rails.logger.info(log_msg)
      rescue StandardError => e
        Rails.logger.error("resources/read: Error reading #{uri} - #{e.message}")
        error_obj = JsonRpcError.new(
          :internal_error,
          message: "Failed to read resource: #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end


    # Sends a call to a tool. Currently logs the call details.
    #
    # @param request_id [String, Integer] The request identifier.
    # @param tool_name [String] The name of the tool.
    # @param params [Hash] The parameters for the tool.
    def send_tools_call(request_id, tool_name, params)
      begin
        tool = ActionMCP::ToolsRegistry.fetch_available_tool(tool_name.to_s)
        Rails.logger.info("Sending tool call: #{tool_name} with params: #{params}")
        # TODO: Implement tool call handling and response if needed.
      rescue StandardError => e
        Rails.logger.error("tools/call: Failed to call tool #{tool_name} - #{e.message}")
        error_obj = JsonRpcError.new(
          :internal_error,
          message: "Failed to call tool #{tool_name}: #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end

    # Sends the prompts list JSON-RPC notification.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_prompts_list(request_id)
      begin
        prompts = format_registry_items(ActionMCP::PromptsRegistry.available_prompts)
        send_jsonrpc_response(request_id, result: {prompts: prompts} )
      rescue StandardError => e
        Rails.logger.error("prompts/list failed: #{e.message}")
        error_obj = JsonRpcError.new(
          :internal_error,
          message: "Failed to list prompts: #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end

    def send_prompts_get(request_id, params)
      prompt_name = params&.fetch("name", nil)
      if prompt_name.nil? || prompt_name.strip.empty?
        Rails.logger.error("prompts/get: 'name' parameter is missing")
        error_obj = JsonRpcError.new(
          :invalid_params,
          message: "Missing 'name' parameter for prompts/get"
        ).as_json
        return send_jsonrpc_response(request_id, error: error_obj)
      end

      begin
        # Assume a method similar to fetch_available_tool exists for prompts.
        prompt = ActionMCP::PromptsRegistry.fetch_available_prompt(prompt_name.to_s)
        if prompt.nil?
          Rails.logger.error("prompts/get: Prompt not found for name #{prompt_name}")
          error_obj = JsonRpcError.new(
            :invalid_params,
            message: "Prompt not found: #{prompt_name}"
          ).as_json
          return send_jsonrpc_response(request_id, error: error_obj)
        end

        result_data = { "prompt" => prompt.to_h }
        send_jsonrpc_response(request_id, result: result_data)
        Rails.logger.info("prompts/get: Returned prompt #{prompt_name}")
      rescue StandardError => e
        Rails.logger.error("prompts/get: Error retrieving prompt #{prompt_name} - #{e.message}")
        error_obj = JsonRpcError.new(
          :internal_error,
          message: "Failed to get prompt: #{e.message}"
        ).as_json
        send_jsonrpc_response(request_id, error: error_obj)
      end
    end


    # Sends a JSON-RPC pong response.
    # We don't actually to send any data back because the spec are not fun anymore.
    #
    # @param request_id [String, Integer] The request identifier.
    def send_pong(request_id)
      send_jsonrpc_response(request_id, result: {})
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
    def send_jsonrpc_notification(method, params = {})
      notification = JsonRpc::Notification.new(method: method, params: params)
      write_message(notification.to_json)
    end

    private

    # Formats registry items to a hash representation.
    #
    # @param registry [Hash] The registry containing tool or prompt definitions.
    # @return [Array<Hash>] The formatted registry items.
    def format_registry_items(registry)
      registry.map { |_, item| item[:class].to_h }
    end

    # Writes a message to the output IO.
    #
    # @param data [String] The data to write.
    def write_message(data)
      Rails.logger.debug("Response Sent: #{data}")
      @output.write("#{data}\n")
    rescue IOError => e
      Rails.logger.error("Failed to write message: #{e.message}")
    end
  end
end

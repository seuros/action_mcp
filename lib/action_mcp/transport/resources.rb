
module ActionMCP
  module Transport
    module Resources
      def send_resources_list(request_id)
        resources = ResourcesBank.all_resources
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

      def send_resource_templates_list(request_id)
        templates = ResourcesBank.all_templates
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
          content = ResourcesBank.read(uri)
          if content.nil?
            ActionMCP.logger.error("resources/read: Resource not found for URI #{uri}")
            error_obj = JsonRpc::JsonRpcError.new(
              :invalid_params,
              message: "Resource not found: #{uri}"
            ).as_json
            return send_jsonrpc_response(request_id, error: error_obj)
          end

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

      def send_roots_list
        send_jsonrpc_request("roots/list")
      end
    end
  end
end

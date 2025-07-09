# frozen_string_literal: true

module ActionMCP
  module Server
    module Resources
      # Send list of available resources to the client
      #
      # @param request_id [String, Integer] The ID of the request to respond to
      #
      # @example Input:
      #   request_id = "req-123"
      #
      # @example Output:
      #   # Sends: {"jsonrpc":"2.0","id":"req-123","result":{"resources":[]}}
      def send_resources_list(request_id)
        send_jsonrpc_response(request_id, result: { resources: [] })
      end

      # Send list of resource templates to the client
      #
      # @param request_id [String, Integer] The ID of the request to respond to
      #
      # @example Input:
      #   request_id = "req-456"
      #
      # @example Output:
      #   # Sends: {"jsonrpc":"2.0","id":"req-456","result":{"resourceTemplates":[{"uriTemplate":"db://{table}","name":"Database Table"}]}}
      def send_resource_templates_list(request_id)
        templates = ActionMCP::ResourceTemplatesRegistry.resource_templates.values.map(&:to_h)
        # TODO: add pagination support
        # TODO add autocomplete
        log_resource_templates
        send_jsonrpc_response(request_id, result: { resourceTemplates: templates })
      end

      # Read and return the contents of a resource
      #
      # @param id [String, Integer] The ID of the request to respond to
      # @param params [Hash] Parameters specifying which resource to read
      #
      # @example Input:
      #   id = "req-789"
      #   params = { uri: "file:///example.txt" }
      #
      # @example Output:
      #   # Sends: {"jsonrpc":"2.0","id":"req-789","result":{"contents":[{"uri":"file:///example.txt","text":"Example content"}]}}
      def send_resource_read(id, params)
        if (template = ResourceTemplatesRegistry.find_template_for_uri(params[:uri]))
          # Create template instance and set execution context
          record = template.process(params[:uri])
          record.with_context({ session: session })

          response = record.call

          if response.error?
            # Convert ResourceResponse errors to JSON-RPC errors
            error_info = response.to_h
            send_jsonrpc_error(id, error_info[:code], error_info[:message], error_info[:data])
          else
            # Handle successful response - ResourceResponse.contents is already an array
            send_jsonrpc_response(id, result: { contents: response.contents.map(&:to_h) })
          end
        else
          send_jsonrpc_error(id, :invalid_params, "Invalid resource URI")
        end
      end

      private

      # Log all registered resource templates
      #
      # @example Input:
      #   # No parameters
      #
      # @example Output:
      #   # Logs: "Registered Resource Templates: ["db://{table}", "file://{path}"]"
      def log_resource_templates
        # Resource templates: #{ActionMCP::ResourceTemplatesRegistry.resource_templates.keys}
      end
    end
  end
end

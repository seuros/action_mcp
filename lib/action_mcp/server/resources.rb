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
        template = ResourceTemplatesRegistry.find_template_for_uri(params[:uri])

        unless template
          send_jsonrpc_error(id, :resource_not_found, "No resource template found for URI: #{params[:uri]}")
          return
        end

        # Check if resource requires consent and if consent is granted
        if template.respond_to?(:requires_consent?) && template.requires_consent? && !session.consent_granted_for?("resource:#{template.name}")
          # Use custom error response for consent required (-32002)
          error = {
            code: -32_002,
            message: "Consent required for resource template '#{template.name}'"
          }
          send_jsonrpc_response(id, error: error)
          return
        end

        begin
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
        rescue StandardError => e
          log_error(e, { resource_uri: params[:uri], template: template.name })
          send_jsonrpc_error(id, :internal_error, "Failed to read resource: #{e.message}")
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
        Rails.logger.debug "Registered Resource Templates: #{ActionMCP::ResourceTemplatesRegistry.resource_templates.keys}"
      end
    end
  end
end

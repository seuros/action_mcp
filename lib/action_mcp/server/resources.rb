# frozen_string_literal: true

module ActionMCP
  module Server
    module Resources
      # Send list of concrete resources to the client.
      # Aggregates resources from templates that implement self.list.
      #
      # @param request_id [String, Integer] The ID of the request to respond to
      # @param params [Hash] Optional params including "cursor" for pagination
      def send_resources_list(request_id, params = {})
        all_resources = collect_resources(request_id)
        return unless all_resources # nil means an error was already sent

        page, next_cursor = paginate(all_resources, cursor: params["cursor"])

        result = { resources: page.map(&:to_h) }
        result[:nextCursor] = next_cursor if next_cursor

        send_jsonrpc_response(request_id, result: result)
      rescue Server::CursorError => e
        send_jsonrpc_error(request_id, :invalid_params, e.message)
      end

      # Send list of resource templates to the client
      #
      # @param request_id [String, Integer] The ID of the request to respond to
      # @param params [Hash] Optional params including "cursor" for pagination
      def send_resource_templates_list(request_id, params = {})
        templates = session.registered_resource_templates.map(&:to_h)
        log_resource_templates

        page, next_cursor = paginate(templates, cursor: params["cursor"])

        result = { resourceTemplates: page }
        result[:nextCursor] = next_cursor if next_cursor

        send_jsonrpc_response(request_id, result: result)
      rescue Server::CursorError => e
        send_jsonrpc_error(request_id, :invalid_params, e.message)
      end

      # Read and return the contents of a resource
      #
      # @param id [String, Integer] The ID of the request to respond to
      # @param params [Hash] Parameters specifying which resource to read
      def send_resource_read(id, params)
        uri = params["uri"]
        template = ResourceTemplatesRegistry.find_template_for_uri(uri)

        unless template
          error = {
            code: -32_002,
            message: "Resource not found",
            data: { uri: uri }
          }
          send_jsonrpc_response(id, error: error)
          return
        end

        # Check if resource requires consent and if consent is granted
        if template.respond_to?(:requires_consent?) && template.requires_consent? && !session.consent_granted_for?("resource:#{template.name}")
          error = {
            code: -32_002,
            message: "Consent required for resource template '#{template.name}'"
          }
          send_jsonrpc_response(id, error: error)
          return
        end

        unless template.readable_uri?(uri)
          error = {
            code: -32_002,
            message: "Resource not found",
            data: { uri: uri }
          }
          send_jsonrpc_response(id, error: error)
          return
        end

        begin
          # Create template instance and set execution context
          record = template.process(uri)
          unless record
            error = {
              code: -32_002,
              message: "Resource not found",
              data: { uri: uri }
            }
            send_jsonrpc_response(id, error: error)
            return
          end

          record.with_context({ session: session })

          response = record.call

          if response.error?
            send_jsonrpc_response(id, error: response.to_h)
          else
            # Normalize contents to MCP ReadResourceResult shape
            contents = response.contents.map { |c| normalize_read_content(c, uri) }
            send_jsonrpc_response(id, result: { contents: contents })
          end
        rescue StandardError => e
          Rails.logger.error "[MCP Error] #{e.class}: #{e.message}"
          send_jsonrpc_error(id, :internal_error, "Failed to read resource: #{e.message}")
        end
      end

      private

      # Collect all concrete resources from templates that implement list.
      # Returns nil if a URI collision error was sent.
      # @return [Array<ActionMCP::Resource>, nil]
      def collect_resources(request_id)
        all_resources = []
        seen_uris = {}

        session.registered_resource_templates.each do |template_class|
          next unless template_class.lists_resources?

          begin
            listed = template_class.list(session: session)
          rescue StandardError => e
            Rails.logger.error "[MCP] Error listing resources from #{template_class.name}: #{e.message}"
            next
          end

          unless listed.is_a?(Array)
            Rails.logger.warn "[MCP] #{template_class.name}.list returned #{listed.class}, expected Array; skipping"
            next
          end

          listed.each do |resource|
            unless resource.is_a?(ActionMCP::Resource)
              Rails.logger.warn "[MCP] #{template_class.name}.list returned non-Resource: #{resource.class}"
              next
            end

            unless template_class.readable_uri?(resource.uri)
              Rails.logger.warn "[MCP] #{template_class.name}.list returned URI not readable by its own template: #{resource.uri}"
              next
            end

            if (existing = seen_uris[resource.uri])
              if existing == resource
                next
              else
                send_jsonrpc_error(request_id, :invalid_params,
                  "Resource URI collision: '#{resource.uri}' listed by multiple templates with conflicting metadata")
                return nil
              end
            end

            seen_uris[resource.uri] = resource
            all_resources << resource
          end
        end

        all_resources
      end

      # Normalize a content object to MCP ReadResourceResult content shape.
      #
      # @return [Hash] with keys: uri, mimeType, and text or blob
      def normalize_read_content(content, _uri)
        case content
        when ActionMCP::Content::Resource
          inner = { uri: content.uri, mimeType: content.mime_type }
          inner[:text] = content.text if content.text
          inner[:blob] = content.blob if content.blob
          inner
        else
          content.respond_to?(:to_h) ? content.to_h : content
        end
      end

      # Log all registered resource templates
      def log_resource_templates
        Rails.logger.debug "Registered Resource Templates: #{ActionMCP::ResourceTemplatesRegistry.resource_templates.keys}"
      end
    end
  end
end

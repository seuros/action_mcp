# frozen_string_literal: true

module ActionMCP
  module Server
    module Resources
      # Default page size for cursor-based pagination
      RESOURCES_PAGE_SIZE = 100

      # Send list of concrete resources to the client.
      # Aggregates resources from templates that implement self.list.
      #
      # @param request_id [String, Integer] The ID of the request to respond to
      # @param params [Hash] Optional params including "cursor" for pagination
      def send_resources_list(request_id, params = {})
        templates = session.registered_resource_templates

        # Collect resources from templates that implement list
        all_resources = []
        seen_uris = {}

        templates.each do |template_class|
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

            # Validate the listed URI is readable by the declaring template
            unless template_class.readable_uri?(resource.uri)
              Rails.logger.warn "[MCP] #{template_class.name}.list returned URI not readable by its own template: #{resource.uri}"
              next
            end

            # Deduplicate by URI
            if (existing = seen_uris[resource.uri])
              if existing == resource
                # Identical duplicate, skip silently
                next
              else
                # Conflicting metadata for same URI
                send_jsonrpc_error(request_id, :invalid_params,
                  "Resource URI collision: '#{resource.uri}' listed by multiple templates with conflicting metadata")
                return
              end
            end

            seen_uris[resource.uri] = resource
            all_resources << resource
          end
        end

        # Apply cursor-based pagination
        result = paginate_resources(all_resources, params["cursor"])
        if result == :invalid_cursor
          send_jsonrpc_error(request_id, :invalid_params, "Invalid cursor value")
          return
        end
        send_jsonrpc_response(request_id, result: result)
      end

      # Send list of resource templates to the client
      #
      # @param request_id [String, Integer] The ID of the request to respond to
      # @param params [Hash] Optional params including "cursor" for pagination
      def send_resource_templates_list(request_id, params = {})
        templates = session.registered_resource_templates.map(&:to_h)
        log_resource_templates

        # Apply cursor-based pagination
        result = paginate_templates(templates, params["cursor"])
        if result == :invalid_cursor
          send_jsonrpc_error(request_id, :invalid_params, "Invalid cursor value")
          return
        end
        send_jsonrpc_response(request_id, result: result)
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

      # Paginate a list of resources with cursor support.
      #
      # @param resources [Array<ActionMCP::Resource>] All resources
      # @param cursor [String, nil] Base64-encoded offset cursor
      # @return [Hash] Result hash with :resources and optional :nextCursor
      def paginate_resources(resources, cursor)
        offset = decode_cursor(cursor)
        return :invalid_cursor if offset == :invalid

        page = resources[offset, RESOURCES_PAGE_SIZE] || []

        result = { resources: page.map(&:to_h) }

        next_offset = offset + RESOURCES_PAGE_SIZE
        if next_offset < resources.size
          result[:nextCursor] = encode_cursor(next_offset)
        end

        result
      end

      # Paginate a list of templates with cursor support.
      #
      # @param templates [Array<Hash>] All template hashes
      # @param cursor [String, nil] Base64-encoded offset cursor
      # @return [Hash] Result hash with :resourceTemplates and optional :nextCursor
      def paginate_templates(templates, cursor)
        offset = decode_cursor(cursor)
        return :invalid_cursor if offset == :invalid

        page = templates[offset, RESOURCES_PAGE_SIZE] || []

        result = { resourceTemplates: page }

        next_offset = offset + RESOURCES_PAGE_SIZE
        if next_offset < templates.size
          result[:nextCursor] = encode_cursor(next_offset)
        end

        result
      end

      # Decode a cursor string to a non-negative integer offset.
      # Returns 0 for nil cursors, :invalid for malformed/negative/non-string values.
      def decode_cursor(cursor)
        return 0 if cursor.nil?
        return :invalid unless cursor.is_a?(String) && !cursor.empty?

        decoded = Base64.strict_decode64(cursor)
        return :invalid unless decoded.match?(/\A\d+\z/)

        decoded.to_i
      rescue ArgumentError
        :invalid
      end

      # Encode an integer offset as a cursor string.
      def encode_cursor(offset)
        Base64.strict_encode64(offset.to_s)
      end

      # Log all registered resource templates
      def log_resource_templates
        Rails.logger.debug "Registered Resource Templates: #{ActionMCP::ResourceTemplatesRegistry.resource_templates.keys}"
      end
    end
  end
end

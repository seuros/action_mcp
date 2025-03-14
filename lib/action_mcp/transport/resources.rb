# frozen_string_literal: true

module ActionMCP
  module Transport
    module Resources
      def send_resources_list(request_id)
        send_jsonrpc_response(request_id, result: { resources: [] })
      end

      def send_resource_templates_list(request_id)
        templates = ActionMCP::ResourceTemplatesRegistry.resource_templates.values.map do |template|
          template.to_h
        end
        # TODO add pagination support
        # TODO add autocomplete
        log_resource_templates
        send_jsonrpc_response(request_id, result: { resourceTemplates: templates })
      end

      def send_resource_read(id, params)
        send_jsonrpc_response(id, result: {})
      end

      def log_resource_templates
        Rails.logger.info("Registered Resource Templates: #{ActionMCP::ResourceTemplatesRegistry.resource_templates.keys}")
      end
    end
  end
end

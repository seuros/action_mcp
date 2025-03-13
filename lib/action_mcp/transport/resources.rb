# frozen_string_literal: true

module ActionMCP
  module Transport
    module Resources
      def send_resources_list(request_id)
        send_jsonrpc_response(request_id, result: {  resources: [] })
      end

      def send_resource_templates_list(request_id)
        send_jsonrpc_response(request_id, result: { templates: [] })
      end

      def send_resource_read(id, params)
        send_jsonrpc_response(id, result: {})
      end
    end
  end
end

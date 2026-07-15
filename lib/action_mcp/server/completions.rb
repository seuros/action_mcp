# frozen_string_literal: true

module ActionMCP
  module Server
    module Completions
      MAX_COMPLETION_VALUES = 100

      def send_completion_complete(request_id, params)
        unless completion_capability?
          send_jsonrpc_error(request_id, :method_not_found, "Completions are not available for this session")
          return
        end

        if (validation_error = ProtocolValidator.request_params_validation_error("completion/complete", params))
          send_jsonrpc_error(request_id, validation_error.code, validation_error.message)
          return
        end

        params = params.with_indifferent_access
        definition = completion_definition(params[:ref], params.dig(:argument, :name))
        unless definition
          send_jsonrpc_error(request_id, :invalid_params, "Unknown completion reference or argument")
          return
        end

        values = matching_completion_values(definition, params.dig(:argument, :value))
        result = {
          completion: {
            values: values.first(MAX_COMPLETION_VALUES),
            total: values.length,
            hasMore: values.length > MAX_COMPLETION_VALUES
          }
        }
        send_jsonrpc_response(request_id, result: result)
      end

      private

      def completion_capability?
        capabilities = (session.server_capabilities || {}).with_indifferent_access
        capabilities.key?(:completions)
      end

      def completion_definition(reference, argument_name)
        case reference[:type]
        when "ref/prompt"
          prompt = session.registered_prompts.find { |candidate| candidate.prompt_name == reference[:name] }
          prompt&.arguments&.find do |argument|
            (argument[:name] || argument["name"]).to_s == argument_name
          end
        when "ref/resource"
          template = session.registered_resource_templates.find do |candidate|
            candidate.uri_template == reference[:uri]
          end
          template&.parameters&.find { |name, _definition| name.to_s == argument_name }&.last
        end
      end

      def matching_completion_values(definition, current_value)
        enum = definition[:enum] || definition["enum"]
        return [] unless enum.is_a?(Array)

        prefix = current_value.downcase
        enum.map(&:to_s).select { |value| value.downcase.start_with?(prefix) }
      end
    end
  end
end

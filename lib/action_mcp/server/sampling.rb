# frozen_string_literal: true

module ActionMCP
  module Server
    module Sampling
      # @param [String] id
      # @param [SamplingRequest] request
      def send_sampling_create_message(id, request)
        params = request.is_a?(SamplingRequest) ? request.to_h : request
        SamplingRequest.validate_params!(params)
        require_client_sampling_support!(params)

        send_jsonrpc_request("sampling/createMessage", params: params, id: id)
      end

      private

      def require_client_sampling_support!(params)
        client_capabilities = session.client_capabilities || {}
        sampling = client_capabilities["sampling"] || client_capabilities[:sampling]
        raise UnsupportedSamplingError, "Client does not support sampling" unless sampling.is_a?(Hash)

        if params.key?(:tools) || params.key?("tools") || params.key?(:toolChoice) || params.key?("toolChoice")
          tools = sampling["tools"] || sampling[:tools]
          raise UnsupportedSamplingError, "Client does not support sampling with tools" unless tools.is_a?(Hash)
        end

        include_context = params[:includeContext] || params["includeContext"]
        if %w[thisServer allServers].include?(include_context)
          context = sampling["context"] || sampling[:context]
          raise UnsupportedSamplingError, "Client does not support sampling context inclusion" unless context.is_a?(Hash)
        end

        return unless params.key?(:task) || params.key?("task")

        tasks = client_capabilities["tasks"] || client_capabilities[:tasks]
        task_requests = tasks.is_a?(Hash) && (tasks["requests"] || tasks[:requests])
        task_sampling = task_requests.is_a?(Hash) && (task_requests["sampling"] || task_requests[:sampling])
        create_message = task_sampling.is_a?(Hash) &&
          (task_sampling["createMessage"] || task_sampling[:createMessage])
        return if create_message.is_a?(Hash)

        raise UnsupportedSamplingError, "Client does not support task-augmented sampling"
      end
    end

    class UnsupportedSamplingError < StandardError; end
  end
end

# frozen_string_literal: true

module ActionMCP
  module Transport
    module Sampling
      # @param [String] id
      # @param [SamplingRequest] request
      def send_sampling_create_message(id, request)
        params = request.is_a?(SamplingRequest) ? request.to_h : request
        send_jsonrpc_request(id, "sampling/createMessage", params)
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class MessagesController < MCPController
    include Instrumentation::ControllerRuntime

    # @route POST / (sse_in)
    def create
      handle_post_message(params, response)
      head response.status
    end

    private

    def transport_handler
      Server::TransportHandler.new(mcp_session)
    end

    def json_rpc_handler
      @json_rpc_handler ||= Server::JsonRpcHandler.new(transport_handler)
    end

    def handle_post_message(params, response)
      filtered_params = filter_jsonrpc_params(params)
      json_rpc_handler.call(filtered_params)
      response.status = :accepted
    rescue StandardError => _e
      response.status = :bad_request
    end

    def mcp_session
      @mcp_session ||= Session.find_or_create_by(id: params[:session_id])
    end

    def filter_jsonrpc_params(params)
      # Valid JSON-RPC keys (both request and response)
      valid_keys = ['jsonrpc', 'method', 'params', 'id', 'result', 'error']

      params.to_h.slice(*valid_keys)
    end
  end
end

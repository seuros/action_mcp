# frozen_string_literal: true

module ActionMCP
  class MessagesController < MCPController
    include Instrumentation::ControllerRuntime

    # @route POST / (sse_in)
    def create
      begin
        handle_post_message(clean_params, response)
      rescue StandardError
        head :internal_server_error
      end
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
      mcp_session.initialize! if params[:method] == "initialize"
      json_rpc_handler.call(params)

      response.status = :accepted
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace.join("\n")
      response.status = :bad_request
    end

    def mcp_session
      @mcp_session ||= Session.find_or_create_by(id: params[:session_id])
    end

    def clean_params
      params.slice(:id, :method, :jsonrpc, :params, :result, :error)
    end
  end
end

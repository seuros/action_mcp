module ActionMCP
  class MessagesController < ApplicationController
    # @route POST / (sse_in)
    def create
      begin
        handle_post_message(clean_params, response)
      rescue => e
        head :internal_server_error
      end
      head response.status
    end

    private

    def transport_handler
      TransportHandler.new(mcp_session)
    end

    def json_rpc_handler
      @json_rpc_handler ||= ActionMCP::JsonRpcHandler.new(transport_handler)
    end

    def handle_post_message(params, response)
      if params[:method] == "initialize"
        mcp_session.initialize!
      end
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

module ActionMCP
  class MessagesController < ApplicationController
    # @route POST / (sse_in)
    def create
      begin
        handle_post_message(params, response)
      rescue => e
        head :internal_server_error
      end
      head response.status
    end

    private

    def transport
      @transport ||= Transport.new(session_key)
    end

    def transport_handler
      TransportHandler.new(transport)
    end

    def json_rpc_handler
      @json_rpc_handler ||= ActionMCP::JsonRpcHandler.new(transport_handler)
    end

    def handle_post_message(params, response)
      json_rpc_handler.call(params)

      response.status = :accepted
    rescue StandardError => e
      response.status = :bad_request
    end

    def session_id
      params[:session_id]
    end

    class Transport
      attr_reader :session_key, :adapter
      def initialize(session_key)
        @session_key = session_key
        @adapter = ActionMCP::Server.server.pubsub
      end

      def write(data)
        adapter.broadcast(session_key, data.to_json)
      end
    end
  end
end

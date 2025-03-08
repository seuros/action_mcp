module ActionMCP
  class MessagesController < ApplicationController
    # @route POST /messages (messages)
    def create
      begin
        handle_post_message(params, response)
      rescue => e
        Rails.logger.error "Error handling message: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render status: :internal_server_error, json: { error: e.message }
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
      puts e.message
      puts e.backtrace
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
        Rails.logger.info "Transport initialized for session: #{session_key}"
      end

      def write(data)
        Rails.logger.info "Transport: Writing data: #{data} in session: #{session_key}"
        adapter.broadcast(session_key, data.to_json)
        Rails.logger.info "Transport: Data broadcast complete"
      end
    end
  end
end

module ActionMCP
  class SSEController < ApplicationController
    HEARTBEAT_INTERVAL = 10
    include ActionController::Live
    delegate :send_endpoint_event, :send_sse_event, :send_ping!, to: :transport

    # @route GET /sse (sse_out)
    def events
      # Set headers first
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"
      TransportRegistry.create(transport)
      # # Register the transport first
      Rails.logger.info "SSE: Registering new connection with session ID: #{session_id}"
      Rails.logger.info "SSE: Transport registered successfully, starting stream"

      begin
        # Now start streaming
        send_endpoint_event(sse_in_url)

        # Keep the connection alive with heartbeat
        while transport.closed? == false
          send_ping!
          sleep HEARTBEAT_INTERVAL
        end
      rescue ActionController::Live::ClientDisconnected, IOError => e
        Rails.logger.info "SSE: Expected disconnection: #{e.message}"
      rescue => e
        Rails.logger.error "SSE: Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      ensure
        transport.close!
      end
    end

    private

    def transport
      @transport ||= Transport::SSEServer.new(response.stream)
    end

    def session_id
      transport.session_id
    end

    def default_url_options
      { host: request.host, port: request.port }
    end
  end
end

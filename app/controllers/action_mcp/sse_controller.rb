module ActionMCP
  class SSEController < ApplicationController
    include ActionController::Live

    # @route GET /sse (sse_out)
    def events
      # Set headers first
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      # Create transport and register session
      transport = TransportHandler::SSEServer.new(response)
      handler = JsonRpcHandler.new(transport)
      transport.onmessage = lambda do |message|
        handler.call(message)
      end

      begin
        # Register the transport first
        Rails.logger.info "SSE: Registering new connection with session ID: #{transport.session_id}"
        Rails.logger.info "SSE: Transport registered successfully, starting stream"
        transport.start

        TransportRegistry.add(transport.session_id, transport)
        # Verify registration was successful
        unless TransportRegistry.get(transport.session_id)
          Rails.logger.error "Failed to register transport"
          raise "Failed to register transport"
        end

        # Now start streaming
        send_endpoint_event(transport)

        # Keep the connection alive with heartbeat
        while response.stream.closed? == false
          transport.send_ping!
          sleep 20
        end
      rescue ActionController::Live::ClientDisconnected, IOError => e
        Rails.logger.info "SSE: Expected disconnection: #{e.message}"
      rescue => e
        Rails.logger.error "SSE: Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      ensure
        cleanup_session(transport)
      end
    end

    private

    def send_endpoint_event(transport)
      endpoint = "#{messages_url}?session_id=#{transport.session_id}"
      transport.send_sse_event("endpoint", endpoint)
    end

    def cleanup_session(transport)
      if transport
        Rails.logger.info "SSE: Cleaning up transport for session: #{transport.session_id}"
        transport.close
        TransportRegistry.remove(transport.session_id)
        response.stream.close rescue nil
      end
    end
  end
end

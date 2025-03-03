# frozen_string_literal: true

module ActionMCP
  module Transport
    class SSEServer < TransportBase
      attr_reader :session_id, :stream

      def initialize(stream)
        @session_id = SecureRandom.hex(6)
        @stream = stream
        @sse_response = nil
        @closed = false
        @json_rpc_handler = JsonRpcHandler.new(self)
      end

      def handle_post_message(params, response)
        @json_rpc_handler.call(params)

        response.status = 202
        response.body = "Accepted"
      rescue StandardError => e
        response.status = 400
        response.body = "Bad Request"
      end

      def send_sse_event(event, data)
        begin
          event_payload = "event: #{event}\n" +
            "data: #{data}\n\n"
          write(event_payload)
          Rails.logger.info "Sent event: #{data}"
        rescue ActionController::Live::ClientDisconnected, IOError => e
          Rails.logger.info "Client disconnected during event send: #{e.message}"
          close!
          raise e
        end
      end

      def send_endpoint_event(messages_url)
        endpoint = "#{messages_url}?session_id=#{session_id}"
        send_sse_event("endpoint", endpoint)
      end

      def send_ping!
        send_sse_event("ping", Time.now.to_s)
      end

      def close!
        @closed = true
        stream.close
      end

      def closed?
        @closed
      end

      private

      delegate :write, to: :stream
    end
  end
end

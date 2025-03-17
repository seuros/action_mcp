# frozen_string_literal: true

module ActionMCP
  module Transport
    class TransportBase
      attr_reader :logger, :client_capabilities, :server_capabilities

      def initialize(logger: Logger.new($stdout))
        @logger = logger
        @on_message = nil
        @on_error = nil
        @client_capabilities = default_capabilities
        @server_capabilities = nil
        @initialize_request_id = SecureRandom.hex(6)
        @initialization_sent = false
      end

      def on_message(&block)
        @on_message = block
      end

      def on_error(&block)
        @on_error = block
      end

      def send_initial_capabilities
        return if @initialization_sent

        log_info("Sending client capabilities: #{@client_capabilities}")

        request = JsonRpc::Request.new(
          id: @initialize_request_id,
          method: "initialize",
          params: {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: @client_capabilities,
            clientInfo: {
              name: user_agent,
              version: ActionMCP.gem_version.to_s
            }
          }
        )
        @initialization_sent = true
        send_message(request.to_json)
      end

      def handle_initialize_response(response)
        return if @server_capabilities

        if response.result
          @server_capabilities = response.result["capabilities"]
          send_initialized_notification
        else
          log_error("Server initialization failed: #{response.error}")
        end
      end

      protected

      def handle_raw_message(raw)
        # Debug - log all raw messages
        log_debug("\e[31m<-- #{raw}\e[0m")

        begin
          msg_hash = MultiJson.load(raw)
          response = nil

          if msg_hash.key?("jsonrpc")
            response = if msg_hash.key?("id")
                         JsonRpc::Response.new(**msg_hash.slice("id", "result", "error").symbolize_keys)
            else
                         JsonRpc::Notification.new(**msg_hash.slice("method", "params").symbolize_keys)
            end
          end
          # Check if this is a response to our initialize request
          if response && @initialize_request_id && response.id == @initialize_request_id
            handle_initialize_response(response)
          elsif response
            @on_message&.call(response)
          end
        rescue MultiJson::ParseError => e
          log_error("JSON parse error: #{e} (raw: #{raw})")
          @on_error&.call(e)
        rescue StandardError => e
          log_error("Error handling message: #{e} (raw: #{raw})")
          @on_error&.call(e)
        end
      end

      # Send the initialized notification to the server
      def send_initialized_notification
        notification = JsonRpc::Notification.new(
          method: "initialized"
        )

        logger.info("Sent initialized notification to server")
        send_message(notification)
      end

      def default_capabilities
        {
          # Base client capabilities
          # roots: {}, # Remove from now.
        }
      end

      def log_debug(message)
        @logger.debug("[#{log_prefix}] #{message}")
      end

      def log_info(message)
        @logger.info("[#{log_prefix}] #{message}")
      end

      def log_error(message)
        @logger.error("[#{log_prefix}] #{message}")
      end

      private

      def log_prefix
        self.class.name.split("::").last
      end
    end
  end
end

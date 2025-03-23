# frozen_string_literal: true

module ActionMCP
  module Client
    # Base client class containing common MCP functionality
    class Base
      # Include all transport protocol modules
      include  Messaging
      include  Tools
      include  Prompts
      include  Resources
      include  Roots
      include  Logging

      attr_reader :logger, :type, :connection_error, :server_capabilities

      def initialize(logger: ActionMCP.logger)
        @logger = logger
        @connected = false
        @initialize_request_id = SecureRandom.uuid_v7
        @server_capabilities = nil
        @message_callback = nil
        @error_callback = nil
        @connection_error = nil
        @initialized = false
      end

      # Connect to the MCP server
      def connect
        return true if @connected

        begin
          log_info("Connecting to MCP server...")
          @connection_error = nil

          # Start transport with proper error handling
          success = start_transport

          unless success
            log_error("Failed to establish connection to MCP server")
            return false
          end

          @connected = true
          log_info("Connected to MCP server")
          true
        rescue StandardError => e
          @connection_error = e.message
          log_error("Failed to connect to MCP server: #{e.message}")
          @error_callback&.call(e)
          false
        end
      end

      # Disconnect from the MCP server
      def disconnect
        return true unless @connected

        begin
          stop_transport
          @connected = false
          log_info("Disconnected from MCP server")
          true
        rescue StandardError => e
          log_error("Error disconnecting from MCP server: #{e.message}")
          @error_callback&.call(e)
          false
        end
      end

      # Set a callback for incoming messages
      def on_message(&block)
        @message_callback = block
      end

      # Set a callback for errors
      def on_error(&block)
        @error_callback = block
      end

      # Send a request to the MCP server
      def write_message(payload)
        unless @connected
          log_error("Cannot send request - not connected")
          return false
        end

        begin
          data = payload.to_json unless payload.is_a?(String)
          send_message(data)
          true
        rescue StandardError => e
          log_error("Failed to send request: #{e.message}")
          @error_callback&.call(e)
          false
        end
      end

      # Methods to be implemented by subclasses
      def start_transport
        raise NotImplementedError, "#{self.class} must implement #start_transport"
      end

      def stop_transport
        raise NotImplementedError, "#{self.class} must implement #stop_transport"
      end

      def send_message(json)
        raise NotImplementedError, "#{self.class} must implement #send_message"
      end

      def ready?
        raise NotImplementedError, "#{self.class} must implement #ready?"
      end

      protected

      def handle_raw_message(raw)
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
          if response && response.id == @initialize_request_id
            handle_initialize_response(response)
          elsif response
            @message_callback&.call(response)
          end
        rescue MultiJson::ParseError => e
          log_error("JSON parse error: #{e} (raw: #{raw})")
          @error_callback&.call(e)
        rescue StandardError => e
          log_error("Error handling message: #{e} (raw: #{raw})")
          @error_callback&.call(e)
        end
      end

      def handle_initialize_response(response)
        return if @initialized

        if response.result
          @server_capabilities = response.result
          send_initialized_notification
          @initialized = true
          log_info("Initialization complete with server capabilities: #{@server_capabilities}")
        else
          log_error("Server initialization failed: #{response.error}")
          @error_callback&.call(StandardError.new("Initialization failed: #{response.error}"))
        end
      end

      def send_initial_capabilities
        log_info("Sending client capabilities")

        request = JsonRpc::Request.new(
          id: @initialize_request_id,
          method: "initialize",
          params: {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: default_capabilities,
            clientInfo: {
              name: user_agent,
              version: ActionMCP.gem_version.to_s
            }
          }
        )

        send_message(request.to_json)
      end

      def send_initialized_notification
        notification = JsonRpc::Notification.new(
          method: "notifications/initialized"
        )

        log_info("Sending initialized notification")
        send_message(notification.to_json)
      end

      def default_capabilities
        {
          # Base client capabilities can be defined here
        }
      end

      def user_agent
        "ActionMCP-#{type}-client"
      end

      def log_debug(message)
        logger.debug("[ActionMCP::#{self.class.name.split('::').last}] #{message}")
      end

      def log_info(message)
        logger.info("[ActionMCP::#{self.class.name.split('::').last}] #{message}")
      end

      def log_error(message)
        logger.error("[ActionMCP::#{self.class.name.split('::').last}] #{message}")
      end

      # Create a promise/future for an async response
      # This implementation uses a simple callback approach
      # You could replace this with a more sophisticated Promise implementation
      def create_response_promise(request_id)
        promise = ResponsePromise.new

        # Store the promise with its request ID
        @pending_responses ||= {}
        @pending_responses[request_id] = promise

        promise
      end

      # Handle incoming responses and resolve the corresponding promises
      def handle_response(response)
        return unless @pending_responses
        puts "response: #{response.inspect}"
        promise = @pending_responses.delete(response.id)
        return unless promise

        if response.error
          promise.reject(response.error)
        else
          promise.resolve(response.result)
        end
      end
    end
  end
end

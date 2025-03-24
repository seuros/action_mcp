# frozen_string_literal: true

require "faraday"
require "uri"

module ActionMCP
  module Client
    # MCP client using Server-Sent Events (SSE) transport
    class SSEClient < Base
      # Define a custom error class for connection issues
      class ConnectionError < StandardError; end

      SSE_TIMEOUT = 10
      ENDPOINT_TIMEOUT = 5 # Seconds

      attr_reader :base_url, :sse_path, :post_url, :session

      def initialize(url, connect: true, logger: ActionMCP.logger, **_options)
        super(logger: logger)
        @type = :sse
        setup_connection(url)
        @buffer = +""
        @stop_requested = false
        @endpoint_received = false
        @endpoint_mutex = Mutex.new
        @endpoint_condition = ConditionVariable.new
        @connection_mutex = Mutex.new
        @connection_condition = ConditionVariable.new

        self.connect if connect
      end

      protected

      def start_transport
        log_debug("Connecting to #{@base_url}#{@sse_path}...")
        @stop_requested = false

        # Reset connection state before starting
        @connection_mutex.synchronize do
          @connected = false
          @connection_error = nil
        end

        # Start connection thread
        @sse_thread = Thread.new { listen_sse }

        # Wait for endpoint
        wait_for_endpoint
      end

      def stop_transport
        log_debug("Stopping SSE connection...")
        @stop_requested = true
        cleanup_sse_thread
      end

      def send_message(json_rpc)
        response = @conn.post(post_url,
                              json_rpc,
                              { "Content-Type" => "application/json" })
        response.success?
      end

      def ready?
        endpoint_ready?
      end

      private

      def setup_connection(url)
        uri = URI.parse(url)
        @base_url = "#{uri.scheme}://#{uri.host}:#{uri.port}"
        @sse_path = uri.path

        @conn = Faraday.new(url: @base_url) do |f|
          f.headers["User-Agent"] = user_agent
          f.options.timeout = nil # No read timeout
          f.options.open_timeout = SSE_TIMEOUT # Connection timeout

          # Use Net::HTTP adapter explicitly as it works well with streaming
          f.adapter :net_http do |http|
            http.read_timeout = nil # No read timeout at adapter level too
            http.open_timeout = SSE_TIMEOUT # Connection timeout
          end
        end

        @post_url = nil
      end

      def wait_for_endpoint
        success = false
        error = nil

        @endpoint_mutex.synchronize do
          unless @endpoint_received
            # Wait with timeout for endpoint
            timeout = @endpoint_condition.wait(@endpoint_mutex, ENDPOINT_TIMEOUT)

            # Handle timeout
            unless timeout || @endpoint_received
              error = "Timeout waiting for MCP endpoint (#{ENDPOINT_TIMEOUT} seconds)"
            end
          end

          success = @endpoint_received
        end

        if error
          log_error(error)
          raise ConnectionError, error
        end

        # If we have the endpoint, consider the connection successful
        if success
          @connection_mutex.synchronize do
            @connected = true
            @connection_condition.broadcast
          end
        end

        success
      end

      def endpoint_ready?
        @endpoint_mutex.synchronize { @endpoint_received }
      end

      def listen_sse
        log_debug("Starting SSE listener...")

        begin
          @conn.get(@sse_path) do |req|
            req.headers["Accept"] = "text/event-stream"
            req.headers["Cache-Control"] = "no-cache"

            req.options.on_data = proc do |chunk, bytes|
              handle_sse_data(chunk, bytes)
            end
          end

          # This should never be reached during normal operation
          # as the SSE connection stays open
        rescue Faraday::ConnectionFailed => e
          handle_connection_error(format_connection_error(e))
        end
      end

      def format_connection_error(error)
        if error.message.include?("Connection refused")
          "Connection refused - server at #{@base_url} is not running or not accepting connections"
        else
          "Connection failed: #{error.message}"
        end
      end

      def connection_error=(message)
        @connection_mutex.synchronize do
          @connection_error = message
          @connection_condition.broadcast
        end
      end

      def handle_connection_error(message)
        log_error("SSE connection failed: #{message}")
        self.connection_error = message
        @connected = false
        @error_callback&.call(StandardError.new(message))
      end

      def handle_sse_data(chunk, _overall_bytes)
        process_chunk(chunk)
        throw :halt if @stop_requested
      end

      def process_chunk(chunk)
        @buffer << chunk
        # If the buffer does not contain a newline but appears to be a complete JSON object,
        # flush it as a complete event.
        if @buffer.strip.match?(/^\{.*\}$/)
          (@current_event ||= []) << @buffer.strip
          @buffer = +""
          return handle_complete_event
        end
        process_buffer while @buffer.include?("\n")
      end

      def process_buffer
        line, _sep, rest = @buffer.partition("\n")
        @buffer = rest

        if line.strip.empty?
          handle_complete_event
        else
          (@current_event ||= []) << line.strip
        end
      end

      def handle_complete_event
        return unless @current_event

        handle_event(@current_event)
        @current_event = nil
      end

      def handle_event(lines)
        event_data = parse_event(lines)
        process_event(event_data)
      end

      def parse_event(lines)
        event_data = { type: "message", data: +"" }
        has_data_prefix = false

        lines.each do |line|
          if line.start_with?("event:")
            event_data[:type] = line.split(":", 2)[1].strip
          elsif line.start_with?("data:")
            has_data_prefix = true
            event_data[:data] << line.split(":", 2)[1].strip
          end
        end

        # If no "data:" prefix was found, treat the entire event as data
        event_data[:data] = lines.join("\n") unless has_data_prefix
        event_data
      end

      def process_event(event_data)
        case event_data[:type]
        when "endpoint" then set_post_endpoint(event_data[:data])
        when "message" then handle_raw_message(event_data[:data])
        else log_error("Unknown event type: #{event_data[:type]}")
        end
      end

      def set_post_endpoint(endpoint_path)
        @post_url = build_post_url(endpoint_path)
        log_debug("Received POST endpoint: #{post_url}")

        # Signal that we have received the endpoint
        @endpoint_mutex.synchronize do
          @endpoint_received = true
          @endpoint_condition.broadcast
        end

        # Now that we have the endpoint, send initial capabilities
        send_initial_capabilities
      end

      def build_post_url(endpoint_path)
        URI.join(@base_url, endpoint_path).to_s
      rescue StandardError
        "#{@base_url}#{endpoint_path}"
      end

      def cleanup_sse_thread
        return unless @sse_thread

        @sse_thread.join(SSE_TIMEOUT) || @sse_thread.kill
      end
    end
  end
end

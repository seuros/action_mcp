# frozen_string_literal: true

require_relative "transport"
require_relative "session_store"

module ActionMCP
  module Client
    # StreamableHTTP transport implementation following MCP specification
    class StreamableHttpTransport < TransportBase
      class ConnectionError < StandardError; end
      class AuthenticationError < StandardError; end

      SSE_TIMEOUT = 10
      ENDPOINT_TIMEOUT = 5

      attr_reader :session_id, :last_event_id, :protocol_version

      def initialize(url, session_store:, session_id: nil, oauth_provider: nil, jwt_provider: nil,
                     protocol_version: nil, **options)
        super(url, session_store: session_store, **options)
        @session_id = session_id
        @oauth_provider = oauth_provider
        @jwt_provider = jwt_provider
        @protocol_version = protocol_version || ActionMCP::DEFAULT_PROTOCOL_VERSION
        @negotiated_protocol_version = nil
        @last_event_id = nil
        @buffer = +""
        @current_event = nil
        @reconnect_attempts = 0
        @max_reconnect_attempts = options[:max_reconnect_attempts] || 3
        @reconnect_delay = options[:reconnect_delay] || 1.0

        setup_http_client
      end

      def connect
        log_debug("Connecting via StreamableHTTP to #{@url}")

        # Load session if session_id provided
        load_session_state if @session_id

        # Start SSE stream if server supports it
        start_sse_stream

        # Set ready first, then connected (so transport is ready when on_connect fires)
        set_ready(true)
        set_connected(true)
        log_debug("StreamableHTTP connection established")
        true
      rescue StandardError => e
        handle_error(e)
        false
      end

      def disconnect
        return true unless connected?

        log_debug("Disconnecting StreamableHTTP")
        stop_sse_stream
        save_session_state if @session_id
        set_connected(false)
        set_ready(false)
        true
      rescue StandardError => e
        handle_error(e)
        false
      end

      def send_message(message)
        raise ConnectionError, "Transport not ready" unless ready?

        headers = build_post_headers
        json_data = message.is_a?(String) ? message : message.to_json

        log_debug("Sending message via POST")
        response = @http_client.post(@url, json_data, headers)

        handle_post_response(response, message)
        true
      rescue StandardError => e
        handle_error(e)
        false
      end

      private

      def setup_http_client
        require "faraday"
        @http_client = Faraday.new do |f|
          f.headers["User-Agent"] = user_agent
          f.options.timeout = nil # No read timeout for SSE
          f.options.open_timeout = SSE_TIMEOUT
          f.adapter :net_http
        end
      end

      def build_get_headers
        headers = {
          "Accept" => "text/event-stream",
          "Cache-Control" => "no-cache"
        }
        headers["mcp-session-id"] = @session_id if @session_id
        headers["Last-Event-ID"] = @last_event_id if @last_event_id

        # Add MCP-Protocol-Version header for GET requests when we have a negotiated version
        headers["MCP-Protocol-Version"] = @negotiated_protocol_version if @negotiated_protocol_version

        headers.merge!(oauth_headers)
        headers.merge!(jwt_headers)
        log_debug("Final GET headers: #{headers}")
        headers
      end

      def build_post_headers
        headers = {
          "Content-Type" => "application/json",
          "Accept" => "application/json, text/event-stream"
        }
        headers["mcp-session-id"] = @session_id if @session_id

        # Add MCP-Protocol-Version header as per 2025-06-18 spec
        # Only include when we have a negotiated version from previous handshake
        headers["MCP-Protocol-Version"] = @negotiated_protocol_version if @negotiated_protocol_version

        headers.merge!(oauth_headers)
        headers.merge!(jwt_headers)
        log_debug("Final POST headers: #{headers}")
        headers
      end

      def start_sse_stream
        log_debug("Starting SSE stream")
        @sse_thread = Thread.new { run_sse_stream }
      end

      def stop_sse_stream
        return unless @sse_thread

        log_debug("Stopping SSE stream")
        @stop_requested = true
        @sse_thread.kill if @sse_thread.alive?
        @sse_thread = nil
        @stop_requested = false
      end

      def run_sse_stream
        headers = build_get_headers

        @http_client.get(@url, nil, headers) do |req|
          req.options.on_data = proc do |chunk, _bytes|
            break if @stop_requested

            process_sse_chunk(chunk)
          end
        end
      rescue StandardError => e
        handle_sse_error(e)
      end

      def process_sse_chunk(chunk)
        @buffer << chunk
        process_complete_events while @buffer.include?("\n\n")
      end

      def process_complete_events
        event_data, _separator, rest = @buffer.partition("\n\n")
        @buffer = rest

        return if event_data.strip.empty?

        parse_sse_event(event_data)
      end

      def parse_sse_event(event_data)
        lines = event_data.split("\n")
        event_id = nil
        data_lines = []

        lines.each do |line|
          if line.start_with?("id:")
            event_id = line[3..].strip
          elsif line.start_with?("data:")
            data_lines << line[5..].strip
          end
        end

        return if data_lines.empty?

        @last_event_id = event_id if event_id

        begin
          message_data = data_lines.join("\n")
          message = MultiJson.load(message_data)
          handle_message(message)
        rescue MultiJson::ParseError => e
          log_error("Failed to parse SSE message: #{e}")
        end
      end

      def handle_post_response(response, _original_message)
        # Extract session ID from response headers
        @session_id = response.headers["mcp-session-id"] if response.headers["mcp-session-id"]

        case response.status
        when 200
          handle_success_response(response)
        when 202
          # Accepted - message received, no immediate response
          log_debug("Message accepted (202)")
        when 401
          handle_authentication_error(response)
          raise AuthenticationError, "Authentication required"
        when 405
          # Method not allowed - server doesn't support this operation
          log_debug("Server returned 405 - operation not supported")
        else
          handle_error_response(response)
        end
      end

      def handle_success_response(response)
        content_type = response.headers["content-type"]

        if content_type&.include?("application/json")
          # Direct JSON response
          handle_json_response(response)
        elsif content_type&.include?("text/event-stream")
          # SSE response stream
          handle_sse_response_stream(response)
        end
      end

      def handle_json_response(response)
        message = MultiJson.load(response.body)

        # Check if this is an initialize response to capture negotiated protocol version
        if message.is_a?(Hash) && message["result"] && message["result"]["protocolVersion"]
          @negotiated_protocol_version = message["result"]["protocolVersion"]
          log_debug("Negotiated protocol version: #{@negotiated_protocol_version}")
        end

        handle_message(message)
      rescue MultiJson::ParseError => e
        log_error("Failed to parse JSON response: #{e}")
      end

      def handle_sse_response_stream(response)
        # Handle SSE stream from POST response
        response.body.each_line do |line|
          process_sse_chunk(line)
        end
      end

      def handle_error_response(response)
        error_msg = +"HTTP #{response.status}: #{response.reason_phrase}"
        error_msg << " - #{response.body}" if response.body && !response.body.empty?
        raise ConnectionError, error_msg
      end

      def handle_sse_error(error)
        log_error("SSE stream error: #{error.message}")

        if should_reconnect?
          schedule_reconnect
        else
          handle_error(error)
        end
      end

      def should_reconnect?
        connected? && @reconnect_attempts < @max_reconnect_attempts
      end

      def schedule_reconnect
        @reconnect_attempts += 1
        delay = @reconnect_delay * @reconnect_attempts

        log_debug("Scheduling SSE reconnect in #{delay}s (attempt #{@reconnect_attempts})")

        Thread.new do
          sleep(delay)
          start_sse_stream unless @stop_requested
        end
      end

      def load_session_state
        session_data = @session_store.load_session(@session_id)
        return unless session_data

        @last_event_id = session_data[:last_event_id]
        log_debug("Loaded session state: last_event_id=#{@last_event_id}")
      end

      def save_session_state
        return unless @session_id

        session_data = {
          id: @session_id,
          last_event_id: @last_event_id,
          session_data: {},
          protocol_version: @protocol_version
        }

        @session_store.save_session(@session_id, session_data)
        log_debug("Saved session state")
      end

      def oauth_headers
        return {} unless @oauth_provider&.authenticated?

        headers = @oauth_provider.authorization_headers
        log_debug("OAuth headers: #{headers}") unless headers.empty?
        headers
      rescue StandardError => e
        log_error("Failed to get OAuth headers: #{e.message}")
        {}
      end

      def jwt_headers
        return {} unless @jwt_provider&.authenticated?

        headers = @jwt_provider.authorization_headers
        log_debug("JWT headers: #{headers}") unless headers.empty?
        headers
      rescue StandardError => e
        log_error("Failed to get JWT headers: #{e.message}")
        {}
      end

      def handle_authentication_error(response)
        # Check for OAuth challenge in WWW-Authenticate header
        www_auth = response.headers["www-authenticate"]
        return unless www_auth&.include?("Bearer")

        if @oauth_provider
          log_debug("Received OAuth challenge, clearing OAuth tokens")
          @oauth_provider.clear_tokens!
        end

        return unless @jwt_provider

        log_debug("Received Bearer challenge, clearing JWT tokens")
        @jwt_provider.clear_tokens!
      end

      def user_agent
        "ActionMCP-StreamableHTTP/#{ActionMCP.gem_version}"
      end
    end
  end
end

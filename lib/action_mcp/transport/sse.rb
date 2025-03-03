require "faraday"
require "uri"

module ActionMCP
  module Transport
    class SSE < TransportBase
      TIMEOUT = 1 # Second

      def initialize(url, **options)
        super(**options)
        setup_connection(url)
        @buffer = ""
        @stop_requested = false
      end

      def start
        log_info("Connecting to #{@base_url}#{@sse_path}...")
        @stop_requested = false
        @sse_thread = Thread.new { listen_sse }
      end

      def send_message(json_rpc)
        validate_post_endpoint
        log_debug("--> #{json_rpc.to_json}")
        send_http_request(json_rpc)
      end

      def stop
        log_info("Stopping SSE connection...")
        @stop_requested = true
        cleanup_sse_thread
      end

      def ready?
        @post_url.present?
      end

      private

      def setup_connection(url)
        uri = URI.parse(url)
        @base_url = "#{uri.scheme}://#{uri.host}:#{uri.port}"
        @sse_path = uri.path
        @conn = Faraday.new(url: @base_url) { |f| f.adapter Faraday.default_adapter }
        @post_url = nil
      end

      def listen_sse
        @conn.get(@sse_path) do |req|
          req.options.on_data = method(:handle_sse_data)
        end
      rescue StandardError => e
        handle_connection_error(e)
      end

      def handle_sse_data(chunk, _overall_bytes)
        process_chunk(chunk)
        throw :halt if @stop_requested
      end

      def process_chunk(chunk)
        @buffer << chunk
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
        event_data = { type: "message", data: "" }

        lines.each do |line|
          if line.start_with?("event:")
            event_data[:type] = line.split(":", 2)[1].strip
          elsif line.start_with?("data:")
            event_data[:data] << line.split(":", 2)[1].strip
          end
        end

        event_data
      end

      def process_event(event_data)
        case event_data[:type]
        when "endpoint" then set_post_endpoint(event_data[:data])
        when "message" then handle_raw_message(event_data[:data])
        when "ping" then log_debug("Received ping")
        else log_error("Unknown event type: #{event_data[:type]}")
        end
      end

      def set_post_endpoint(endpoint_path)
        @post_url = build_post_url(endpoint_path)
        log_info("Received POST endpoint: #{@post_url}")
        send_initial_capabilities
      end

      def build_post_url(endpoint_path)
        URI.join(@base_url, endpoint_path).to_s
      rescue StandardError
        "#{@base_url}#{endpoint_path}"
      end

      def send_initial_capabilities
        request = JsonRpc::Request.new(
          id: 1,
          method: "initialize",
          params: {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: [],
            clientInfo: {
              name: ActionMCP.name,
              version: ActionMCP.gem_version
            }
          }
        )
        send_message(request)
      end

      def validate_post_endpoint
        raise "MCP endpoint not set (no 'endpoint' event received)" unless @post_url
      end

      def send_http_request(json_rpc)
        response = @conn.post(@post_url, json_rpc.to_json, { "Content-Type" => "application/json" })
        handle_http_response(response)
      end

      def handle_http_response(response)
        unless response.success?
          log_error("HTTP POST failed: #{response.status} - #{response.body}")
        end
      end

      def handle_connection_error(error)
        log_error("Connection error: #{error}")
        @on_error&.call(error)
      end

      def cleanup_sse_thread
        return unless @sse_thread

        @sse_thread.join(TIMEOUT) || @sse_thread.kill
      end
    end
  end
end

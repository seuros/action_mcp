# frozen_string_literal: true

module ActionMCP
  # Base handler for common functionality
  class BaseJsonRpcHandler
    delegate :initialize!, :initialized?, to: :transport
    delegate :write, :read, to: :transport
    attr_reader :transport

    # @param transport [ActionMCP::TransportHandler]
    def initialize(transport)
      @transport = transport
    end

    # Process a single line of input.
    # @param line [String, Hash]
    def call(line)
      request = parse_request(line)
      return unless request

      process_request(request)
    end

    protected

    def parse_request(line)
      if line.is_a?(String)
        line.strip!
        return if line.empty?

        begin
          MultiJson.load(line)
        rescue MultiJson::ParseError => e
          Rails.logger.error("Failed to parse JSON: #{e.message}")
          nil
        end
      else
        line
      end
    end

    # @param request [Hash]
    def process_request(request)
      unless request["jsonrpc"] == "2.0"
        puts "Invalid request: #{request}"
        return
      end
      read(request)
      return if request["error"]
      return if request["result"] == {} # Probably a pong

      rpc_method = request["method"]
      id = request["id"]
      params = request["params"]

      # Common methods (both directions)
      case rpc_method
      when "ping"                      # [BOTH] Ping message
        transport.send_pong(id)
      when "initialize"                # [BOTH] Initialization
        handle_initialize(id, params)
      when %r{^notifications/}
        process_common_notifications(rpc_method, params)
      else
        handle_specific_method(rpc_method, id, params)
      end
    end

    # Override in subclasses
    def handle_initialize(id, params)
      raise NotImplementedError, "Subclasses must implement #handle_initialize"
    end

    # Override in subclasses
    def handle_specific_method(rpc_method, id, params)
      raise NotImplementedError, "Subclasses must implement #handle_specific_method"
    end

    def process_common_notifications(rpc_method, params)
      case rpc_method
      when "notifications/initialized"            # [BOTH] Initialization complete
        puts "Initialized"
        transport.initialize!
      when "notifications/cancelled"              # [BOTH] Request cancellation
        puts "Request #{params['requestId']} cancelled: #{params['reason']}"
        # Handle cancellation
      else
        handle_specific_notification(rpc_method, params)
      end
    end

    # Override in subclasses
    def handle_specific_notification(rpc_method, params)
      raise NotImplementedError, "Subclasses must implement #handle_specific_notification"
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class JsonRpcHandler
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
      request = if line.is_a?(String)
                  line.strip!
                  return if line.empty?

                  begin
                    MultiJson.load(line)
                  rescue MultiJson::ParseError => e
                    Rails.logger.error("Failed to parse JSON: #{e.message}")
                    return
                  end
      else
                  line
      end
      process_request(request)
    end

    protected

    # Validate if the request follows JSON-RPC 2.0 specification
    # @param request [Hash]
    # @return [Boolean]
    def valid_request?(request)
      if request["jsonrpc"] != "2.0"
        puts "Invalid request: #{request}"
        return false
      end
      true
    end

    # Handle common methods for both client and server
    # @param rpc_method [String]
    # @param id [String, Integer]
    # @param params [Hash]
    # @return [Boolean] true if handled, false otherwise
    def handle_common_methods(rpc_method, id, params)
      case rpc_method
      when "ping"
        transport.send_pong(id)
        true
      when %r{^notifications/}
        puts "\e[31mProcessing notifications\e[0m"
        process_notifications(rpc_method, params)
        true
      else
        false
      end
    end

    # Method to be overridden by subclasses to handle specific RPC methods
    # @param rpc_method [String]
    # @param id [String, Integer]
    # @param params [Hash]
    def handle_method(rpc_method, id, params)
      raise NotImplementedError, "Subclasses must implement handle_method"
    end

    private

    # @param request [Hash]
    def process_request(request)
      return unless valid_request?(request)

      read(request)
      return if request["error"]
      return if request["result"] == {} # Probably a pong

      rpc_method = request["method"]
      id = request["id"]
      params = request["params"]

      # Try to handle common methods first
      return if handle_common_methods(rpc_method, id, params)

      # Delegate to subclass-specific handling
      handle_method(rpc_method, id, params)
    end

    def process_notifications(rpc_method, params)
      case rpc_method
      when "notifications/cancelled"              # [BOTH] Request cancellation
        puts "\e[31m Request #{params['requestId']} cancelled: #{params['reason']}\e[0m"
        # we don't need to do anything here
      else
        Rails.logger.warn("Unknown notifications method: #{rpc_method}")
      end
    end
  end
end

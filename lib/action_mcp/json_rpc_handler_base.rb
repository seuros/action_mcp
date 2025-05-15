# frozen_string_literal: true

module ActionMCP
  class JsonRpcHandlerBase
    module Methods
      # Common methods
      PING = "ping"

      # Server methods
      INITIALIZE = "initialize"
      COMPLETION_COMPLETE = "completion/complete"

      # Resource methods
      RESOURCES_LIST = "resources/list"
      RESOURCES_TEMPLATES_LIST = "resources/templates/list"
      RESOURCES_READ = "resources/read"
      RESOURCES_SUBSCRIBE = "resources/subscribe"
      RESOURCES_UNSUBSCRIBE = "resources/unsubscribe"

      # Prompt methods
      PROMPTS_GET = "prompts/get"
      PROMPTS_LIST = "prompts/list"

      # Tool methods
      TOOLS_LIST = "tools/list"
      TOOLS_CALL = "tools/call"

      # Notification methods
      NOTIFICATIONS_INITIALIZED = "notifications/initialized"
      NOTIFICATIONS_CANCELLED = "notifications/cancelled"
    end

    delegate :initialize!, :initialized?, to: :transport
    delegate :write, :read, to: :transport
    attr_reader :transport

    # @param transport [ActionMCP::TransportHandler]
    def initialize(transport)
      @transport = transport
    end

    # Process a request object.
    # @param request [JSON_RPC::Request, JSON_RPC::Notification, JSON_RPC::Response]
    def call(request)
      raise NotImplementedError, "Subclasses must implement call"
    end

    protected

    # Handle common methods for both client and server
    # @param rpc_method [String]
    # @param id [String, Integer]
    # @param params [Hash]
    # @return [Boolean] true if handled, false otherwise
    def handle_common_methods(rpc_method, id, params)
      case rpc_method
      when Methods::PING
        transport.send_pong(id)
        true
      when %r{^notifications/}
        process_notifications(rpc_method, params)
        true
      else
        false
      end
    end

    # Process notification methods
    def process_notifications(rpc_method, params)
      case rpc_method
      when Methods::NOTIFICATIONS_CANCELLED
        handle_cancelled_notification(params)
      else
        Rails.logger.warn("Unknown notifications method: #{rpc_method}")
      end
    end

    private

    # Handle cancelled notification
    def handle_cancelled_notification(params)
      Rails.logger.warn "\e[31m Request #{params['requestId']} cancelled: #{params['reason']}\e[0m"
      # we don't need to do anything here
    end
  end
end

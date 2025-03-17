# frozen_string_literal: true

module ActionMCP
  # Handler for client-side requests (server -> client)
  class ClientJsonRpcHandler < BaseJsonRpcHandler
    def handle_initialize(id, params)
      # Client-specific initialization
      transport.send_client_capabilities(id, params)
    end

    def handle_specific_method(rpc_method, id, params)
      case rpc_method
      when "client/setLoggingLevel" # [CLIENT] Server configuring client logging
        transport.set_client_logging_level(id, params["level"])
      when %r{^roots/}                 # [CLIENT] Roots management
        process_roots(rpc_method, id, params)
      when %r{^sampling/}              # [CLIENT] Sampling requests
        process_sampling(rpc_method, id, params)
      else
        Rails.logger.warn("Unknown client method: #{rpc_method}")
      end
    end

    def handle_specific_notification(rpc_method, params)
      case rpc_method
      when "notifications/resources/updated" # [CLIENT] Resource update notification
        puts "Resource #{params['uri']} was updated"
        # Handle resource update notification
      when "notifications/tools/list_changed" # [CLIENT] Tool list change notification
        puts "Tool list has changed"
        # Handle tool list change notification
      when "notifications/prompts/list_changed" # [CLIENT] Prompt list change notification
        puts "Prompt list has changed"
        # Handle prompt list change notification
      when "notifications/resources/list_changed" # [CLIENT] Resource list change notification
        puts "Resource list has changed"
        # Handle resource list change notification
      else
        Rails.logger.warn("Unknown client notification: #{rpc_method}")
      end
    end

    private

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_roots(rpc_method, id, params)
      case rpc_method
      when "roots/list"               # [CLIENT] List available roots
        transport.send_roots_list(id)
      else
        Rails.logger.warn("Unknown roots method: #{rpc_method}")
      end
    end

    # @param rpc_method [String]
    # @param id [String]
    # @param params [Hash]
    def process_sampling(rpc_method, id, params)
      case rpc_method
      when "sampling/createMessage" # [CLIENT] Create a message using AI
        transport.send_sampling_create_message(id, params)
      else
        Rails.logger.warn("Unknown sampling method: #{rpc_method}")
      end
    end
  end
end

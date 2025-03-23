# frozen_string_literal: true

module ActionMCP
  class JsonRpcClientHandler < JsonRpcHandler
    protected

    # Handle client-specific methods
    # @param rpc_method [String]
    # @param id [String, Integer]
    # @param params [Hash]
    def handle_method(rpc_method, id, params)
      case rpc_method
      when "client/setLoggingLevel"    # Server configuring client logging
        process_client_logging(id, params)
      when %r{^roots/}                 # Roots management
        process_roots(rpc_method, id)
      when %r{^sampling/}              # Sampling requests
        process_sampling(rpc_method, id, params)
      else
        puts "\e[31mUnknown server method: #{rpc_method}\e[0m"
      end
    end



    # @param id [String]
    # @param params [Hash]
    def process_client_logging(id, params)
      level = params["level"]
      transport.set_client_logging_level(id, level)
    end

    # @param rpc_method [String]
    # @param id [String]
    def process_roots(rpc_method, id)
      case rpc_method
      when "roots/list" # List available roots
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
      when "sampling/createMessage" # Create a message using AI
        # @param id [String]
        # @param params [SamplingRequest]
        transport.send_sampling_create_message(id, params)
      else
        Rails.logger.warn("Unknown sampling method: #{rpc_method}")
      end
    end


    # @param rpc_method [String]
    def process_notifications(rpc_method, params)
      case rpc_method
      when "notifications/resources/updated" # Resource update notification
        puts "\e[31m Resource #{params['uri']} was updated\e[0m"
        # Handle resource update notification
        # TODO: fetch updated resource or mark it as stale
      when "notifications/tools/list_changed" # Tool list change notification
        puts "\e[31m Tool list has changed\e[0m"
        # Handle tool list change notification
        # TODO: fetch new tools or mark them as stale
      when "notifications/prompts/list_changed" # Prompt list change notification
        puts "\e[31m Prompt list has changed\e[0m"
        # Handle prompt list change notification
        # TODO: fetch new prompts or mark them as stale
      when "notifications/resources/list_changed" # Resource list change notification
        puts "\e[31m Resource list has changed\e[0m"
        # Handle resource list change notification
        # TODO: fetch new resources or mark them as stale
      else
        super
      end
    end
  end
end

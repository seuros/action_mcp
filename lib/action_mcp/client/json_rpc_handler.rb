# frozen_string_literal: true

module ActionMCP
  module Client
    class JsonRpcHandler < JsonRpcHandlerBase
      attr_reader :client

      def initialize(transport, client)
        super(transport)
        @client = client
      end

      protected

      # Handle client-specific methods
      # @param rpc_method [String]
      # @param id [String, Integer]
      # @param params [Hash]
      def handle_method(rpc_method, id, params)
        puts "\e[31mUnknown server method: #{rpc_method} #{id} #{params}\e[0m"
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

      def process_response(id, result)
        if transport.id == id
          ## This initializes the transport
          client.server = Client::Server.new(result)
          return send_initialized_notification
        end

        request = transport.messages.requests.find_by(jsonrpc_id: id)
        return unless request

        # Mark the request as acknowledged
        request.update(request_acknowledged: true)

        case request.rpc_method
        when "tools/list"
          client.toolbox.tools = result["tools"]
          return true
        when "prompts/list"
          client.prompt_book.prompts = result["prompts"]
          return true
        when "resources/list"
          client.catalog.resources = result["resources"]
          return true
        when "resources/templates/list"
          client.blueprint.templates = result["resourceTemplates"]
          return true
        end

        puts "\e[31mUnknown response: #{id} #{result}\e[0m"
      end

      def process_error(id, error)
        # Do something ?
        puts "\e[31mUnknown error: #{id} #{error}\e[0m"
      end

      def send_initialized_notification
        transport.initialize!
        client.send_jsonrpc_notification("notifications/initialized")
      end
    end
  end
end

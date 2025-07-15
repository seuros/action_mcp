# frozen_string_literal: true

module ActionMCP
  module Client
    class JsonRpcHandler < JsonRpcHandlerBase
      attr_reader :client

      def initialize(transport, client)
        super(transport)
        @client = client
      end

      # Handle client-side JSON-RPC requests/responses
      # @param request [JSON_RPC::Request, JSON_RPC::Notification, JSON_RPC::Response]
      def call(request)
        case request
        when JSON_RPC::Request
          handle_request(request)
        when JSON_RPC::Notification
          handle_notification(request)
        when JSON_RPC::Response
          handle_response(request)
        end
      end

      private

      def handle_request(request)
        id = request.id
        rpc_method = request.method
        params = request.params

        handle_method(rpc_method, id, params)
      end

      def handle_notification(notification)
        # Handle server notifications to client
        client.log_debug("Received notification: #{notification.method}")
      end

      def handle_response(response)
        # Handle server responses to client requests
        client.log_debug("Received response: #{response.id} - #{response.result ? 'success' : 'error'}")
      end

      protected

      # Handle client-specific methods
      # @param rpc_method [String]
      # @param id [String, Integer]
      # @param params [Hash]
      def handle_method(rpc_method, id, params)
        case rpc_method
        when Methods::ELICITATION_CREATE
          client.process_elicitation_request(id, params)
        when %r{^roots/}
          process_roots(rpc_method, id)
        when %r{^sampling/}
          process_sampling(rpc_method, id, params)
        else
          common_result = handle_common_methods(rpc_method, id, params)
          client.log_warn("Unknown server method: #{rpc_method} #{id} #{params}") if common_result.nil?
        end
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
          client.log_debug("Resource #{params['uri']} was updated")
          # Handle resource update notification
          # TODO: fetch updated resource or mark it as stale
        when "notifications/tools/list_changed" # Tool list change notification
          client.log_debug("Tool list has changed")
          # Handle tool list change notification
          # TODO: fetch new tools or mark them as stale
        when "notifications/prompts/list_changed" # Prompt list change notification
          client.log_debug("Prompt list has changed")
          # Handle prompt list change notification
          # TODO: fetch new prompts or mark them as stale
        when "notifications/resources/list_changed" # Resource list change notification
          client.log_debug("Resource list has changed")
          # Handle resource list change notification
          # TODO: fetch new resources or mark them as stale
        else
          super
        end
      end

      def process_response(id, result)
        # Check if this is a response to an initialize request
        # We need to check the actual request method, not just compare IDs
        request = client.session ? transport.messages.requests.find_by(jsonrpc_id: id) : nil

        # If no session yet, this might be the initialize response
        if !client.session && result["serverInfo"]
          handle_initialize_response(id, result)
          return send_initialized_notification
        end

        return unless request

        # Mark the request as acknowledged
        request.update(request_acknowledged: true)

        case request.rpc_method
        when "tools/list"
          client.toolbox.tools = result["tools"]
          client.toolbox.instance_variable_set(:@next_cursor, result["nextCursor"])
          client.toolbox.instance_variable_set(:@total, result["tools"]&.size || 0)
          return true
        when "prompts/list"
          client.prompt_book.prompts = result["prompts"]
          client.prompt_book.instance_variable_set(:@next_cursor, result["nextCursor"])
          client.prompt_book.instance_variable_set(:@total, result["prompts"]&.size || 0)
          return true
        when "resources/list"
          client.catalog.resources = result["resources"]
          client.catalog.instance_variable_set(:@next_cursor, result["nextCursor"])
          client.catalog.instance_variable_set(:@total, result["resources"]&.size || 0)
          return true
        when "resources/templates/list"
          client.blueprint.templates = result["resourceTemplates"]
          client.blueprint.instance_variable_set(:@next_cursor, result["nextCursor"])
          client.blueprint.instance_variable_set(:@total, result["resourceTemplates"]&.size || 0)
          return true
        end

        client.log_warn("Unknown response: #{id} #{result}")
      end

      def process_error(id, error)
        # Do something ?
        client.log_error("Unknown error: #{id} #{error}")
      end

      def handle_initialize_response(_request_id, result)
        # Session ID comes from HTTP headers, not the response body
        # The transport should have already extracted it
        session_id = transport.instance_variable_get(:@session_id)

        if session_id.nil?
          client.log_error("No session ID received from server")
          return
        end

        # Check if we're resuming an existing session
        if client.instance_variable_get(:@session_id) && session_id == client.instance_variable_get(:@session_id)
          # We're resuming an existing session
          client.instance_variable_set(:@session, ActionMCP::Session.find(session_id))
          client.log_info("Resumed existing session: #{session_id}")
        else
          # Create a new session with the server-provided ID
          client.instance_variable_set(:@session, ActionMCP::Session.from_client.new(
                                                    id: session_id,
                                                    protocol_version: result["protocolVersion"] || ActionMCP::DEFAULT_PROTOCOL_VERSION,
                                                    client_info: client.client_info,
                                                    client_capabilities: client.client_capabilities,
                                                    server_info: result["serverInfo"],
                                                    server_capabilities: result["capabilities"]
                                                  ))
          client.session.save
          client.log_info("Created new session: #{session_id}")
        end

        # Set the server info
        client.server = Client::Server.new(result)
        client.instance_variable_set(:@initialized, true)
      end

      def send_initialized_notification
        transport.initialize! if transport.respond_to?(:initialize!)
        client.send_jsonrpc_notification("notifications/initialized")
      end
    end
  end
end

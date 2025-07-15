# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      class Router
        def initialize(handler)
          @handler = handler
        end

        def route(rpc_method, id, params)
          case rpc_method
          when "initialize"
            @handler.handle_initialize(id, params)
          when %r{^prompts/}
            @handler.process_prompts(rpc_method, id, params)
          when %r{^resources/}
            @handler.process_resources(rpc_method, id, params)
          when %r{^tools/}
            @handler.process_tools(rpc_method, id, params)
          when "completion/complete"
            @handler.process_completion_complete(id, params)
          else
            raise ActionMCP::Server::JSON_RPC::JsonRpcError.new(:method_not_found,
                                                                message: "Method not found: #{rpc_method}")
          end
        end
      end
    end
  end
end

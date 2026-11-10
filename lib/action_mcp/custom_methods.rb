# frozen_string_literal: true

module ActionMCP
  # Registry of vendor JSON-RPC methods served next to the MCP core methods.
  #
  # Names take the form "vendor/method" and the vendor segment stays clear of the
  # MCP namespaces, so a spec revision can never collide with an application method.
  # The handler receives the request params and the session; its return value
  # becomes the JSON-RPC result. Raise JSON_RPC::JsonRpcError to answer with a
  # specific error code.
  #
  # @example config/initializers/action_mcp.rb
  #   ActionMCP.configure do |config|
  #     config.register_method("acme/toolsets/list") do |params, session|
  #       { toolsets: Toolset.visible_to(ActionMCP::Current.user).as_json }
  #     end
  #   end
  class CustomMethods
    RESERVED_NAMESPACES = %w[
      completion elicitation initialize logging notifications ping
      prompts resources roots sampling tasks tools
    ].freeze

    NAME_FORMAT = %r{\A[a-z0-9][a-z0-9_.-]*/[a-z0-9_./-]*[a-z0-9_]\z}i

    def initialize
      @handlers = {}
    end

    def register(name, callable = nil, &block)
      name = name.to_s
      handler = callable || block

      raise ArgumentError, "Custom method '#{name}' needs a handler responding to #call" unless handler.respond_to?(:call)
      raise ArgumentError, "Custom method '#{name}' must look like 'vendor/method'" unless name.match?(NAME_FORMAT)

      namespace = name.split("/", 2).first
      if RESERVED_NAMESPACES.include?(namespace.downcase)
        raise ArgumentError, "Custom method '#{name}' uses the reserved MCP namespace '#{namespace}/'"
      end

      @handlers[name] = handler
    end

    def unregister(name)
      @handlers.delete(name.to_s)
    end

    def [](name)
      @handlers[name.to_s]
    end

    def names
      @handlers.keys
    end

    def clear
      @handlers.clear
    end
  end
end

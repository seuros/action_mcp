# frozen_string_literal: true

module ActionMCP
  module Client
    class Server
      attr_reader :name, :version, :server_info, :capabilities

      def initialize(data)
        # Store protocol version if needed for later use
        @protocol_version = data["protocolVersion"]

        # Extract server information
        @server_info = data["serverInfo"] || {}
        @name = server_info["name"]
        @version = server_info["version"]

        # Store capabilities for dynamic checking
        @capabilities = data["capabilities"] || {}
      end

      # Check if 'tools' capability is present
      def tools?
        @capabilities.key?("tools")
      end

      # Check if 'prompts' capability is present
      def prompts?
        @capabilities.key?("prompts")
      end

      # Check if tools have a dynamic state based on listChanged flag
      def dynamic_tools?
        tool_cap = @capabilities["tools"] || {}
        tool_cap["listChanged"] == true
      end

      # Check if logging capability exists
      def logging?
        @capabilities.key?("logging")
      end

      # Check if resources capability exists
      def resources?
        @capabilities.key?("resources")
      end

      # Check if resources have a dynamic state based on listChanged flag
      def dynamic_resources?
        resources_cap = @capabilities["resources"] || {}
        resources_cap["listChanged"] == true
      end

      def inspect
        "#<#{self.class.name} name: #{name}, version: #{version} with resources: #{resources?}, tools: #{tools?}, prompts: #{prompts?}, logging: #{logging?}>"
      end

      alias to_s inspect
    end
  end
end

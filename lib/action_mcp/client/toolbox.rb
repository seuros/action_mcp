# frozen_string_literal: true

module ActionMCP
  module Client
    # Toolbox
    #
    # A collection that manages and provides access to tools from the server.
    # This class stores tool definitions along with their input schemas and
    # provides methods for retrieving, filtering, and accessing tools.
    #
    # Example usage:
    #   tools_data = client.list_tools # Returns array of tool definitions
    #   toolbox = Toolbox.new(tools_data)
    #
    #   # Access a specific tool by name
    #   weather_tool = toolbox.find("weather_forecast")
    #
    #   # Get all tools matching a criteria
    #   calculation_tools = toolbox.filter { |t| t.name.include?("calculate") }
    #
    class Toolbox < Collection
      # Initialize a new Toolbox with tool definitions
      #
      # @param tools [Array<Hash>] Array of tool definition hashes, each containing
      #   name, description, and inputSchema keys
      def initialize(tools, client)
        super(tools, client)
        self.tools = @collection_data
        @load_method = :list_tools
      end

      # Find a tool by name
      #
      # @param name [String] Name of the tool to find
      # @return [Tool, nil] The tool with the given name, or nil if not found
      def find(name)
        all.find { |tool| tool.name == name }
      end

      # Filter tools based on a given block
      #
      # @yield [tool] Block that determines whether to include a tool
      # @yieldparam tool [Tool] A tool from the collection
      # @yieldreturn [Boolean] true to include the tool, false to exclude it
      # @return [Array<Tool>] Tools that match the filter criteria
      def filter(&block)
        all.select(&block)
      end

      # Get a list of all tool names
      #
      # @return [Array<String>] Names of all tools in the collection
      def names
        all.map(&:name)
      end

      # Number of tools in the collection
      #
      # @return [Integer] The number of tools
      def size
        all.size
      end

      # Check if the collection contains a tool with the given name
      #
      # @param name [String] The tool name to check for
      # @return [Boolean] true if a tool with the name exists
      def contains?(name)
        all.any? { |tool| tool.name == name }
      end

      # Get tools by category or type
      #
      # @param keyword [String] Keyword to search for in tool names and descriptions
      # @return [Array<Tool>] Tools containing the keyword
      def search(keyword)
        all.select do |tool|
          tool.name.include?(keyword) ||
            tool.description&.downcase&.include?(keyword.downcase)
        end
      end

      # Generate a hash representation of all tools in the collection based on provider format
      #
      # @param provider [Symbol] The provider format to use (:claude, :openai, or :default)
      # @return [Hash] Hash containing all tools formatted for the specified provider
      def to_h(provider = :default)
        case provider
        when :claude
          # Claude format
          { "tools" => all.map(&:to_claude_h) }
        when :openai
          # OpenAI format
          { "tools" => all.map(&:to_openai_h) }
        else
          # Default format (same as original)
          { "tools" => all.map(&:to_h) }
        end
      end

      def tools=(tools)
        @collection_data = tools.map { |tool_data| Tool.new(tool_data) }
      end

      # Internal Tool class to represent individual tools
      class Tool
        attr_reader :name, :description, :input_schema, :annotations

        # Initialize a new Tool instance
        #
        # @param data [Hash] Tool definition hash containing name, description, and inputSchema
        #  and optionally annotations
        def initialize(data)
          @name = data["name"]
          @description = data["description"]
          @input_schema = data["inputSchema"] || {}
          @annotations = data["annotations"] || {}
        end

        # Get all required properties for this tool
        #
        # @return [Array<String>] Array of required property names
        def required_properties
          @input_schema["required"] || []
        end

        # Get all properties for this tool
        #
        # @return [Hash] Hash of property definitions
        def properties
          @input_schema["properties"] || {}
        end

        # Check if the tool requires a specific property
        #
        # @param name [String] Name of the property to check
        # @return [Boolean] true if the property is required
        def requires?(name)
          required_properties.include?(name)
        end

        # Check if the tool has a specific property
        #
        # @param name [String] Name of the property to check
        # @return [Boolean] true if the property exists
        def has_property?(name)
          properties.key?(name)
        end

        # Get property details by name
        #
        # @param name [String] Name of the property
        # @return [Hash, nil] Property details or nil if not found
        def property(name)
          properties[name]
        end

        # Generate a hash representation of the tool (default format)
        #
        # @return [Hash] Hash containing tool details
        def to_h
          {
            "name" => @name,
            "description" => @description,
            "inputSchema" => @input_schema,
            "annotations" => @annotations
          }
        end

        # Generate a hash representation of the tool in Claude format
        #
        # @return [Hash] Hash containing tool details formatted for Claude
        def to_claude_h
          {
            "name" => @name,
            "description" => @description,
            "input_schema" => @input_schema.transform_keys { |k| k == "inputSchema" ? "input_schema" : k },
            "annotations" => @annotations
          }
        end

        # Generate a hash representation of the tool in OpenAI format
        #
        # @return [Hash] Hash containing tool details formatted for OpenAI
        def to_openai_h
          {
            "type" => "function",
            "function" => {
              "name" => @name,
              "description" => @description,
              "parameters" => @input_schema,
              "annotations" => @annotations
            }
          }
        end
      end
    end
  end
end

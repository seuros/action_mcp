# frozen_string_literal: true
module ActionMCP
  module Client
    # Blueprints
    #
    # A collection that manages and provides access to URI templates (blueprints) for Model Context Protocol (MCP)
    # resource discovery. These blueprints allow dynamic construction of resource URIs by filling in
    # variable placeholders with specific values.
    #
    # Example usage:
    #   template_data = client.list_resource_templates # Returns array of URI template definitions
    #   blueprints = Blueprints.new(template_data)
    #
    #   # Access a specific blueprint by pattern
    #   file_blueprint = blueprints.find_by_pattern("file://{path}")
    #
    #   # Generate a concrete URI from a blueprint with parameters
    #   uri = blueprints.construct("file://{path}", { path: "/logs/app.log" })
    #
    class Blueprint
      # Initialize a new Blueprints collection with URI template definitions
      #
      # @param templates [Array<Hash>] Array of URI template definition hashes, each containing
      #   uriTemplate, name, description, and optionally mimeType keys
      def initialize(templates = [])
        @blueprints = templates.map { |template_data| ResourceTemplate.new(template_data) }
      end

      # Return all URI templates in the collection
      #
      # @return [Array<Blueprint>] All blueprint objects in the collection
      def all
        @blueprints
      end

      # Find a blueprint by its URI pattern
      #
      # @param pattern [String] URI template pattern to find
      # @return [Blueprint, nil] The blueprint with the given pattern, or nil if not found
      def find_by_pattern(pattern)
        @blueprints.find { |blueprint| blueprint.pattern == pattern }
      end

      # Find blueprints by name
      #
      # @param name [String] Name of the blueprints to find
      # @return [Array<Blueprint>] Blueprints with the given name
      def find_by_name(name)
        @blueprints.select { |blueprint| blueprint.name == name }
      end

      # Construct a concrete URI by applying parameters to a blueprint
      #
      # @param pattern [String] URI template pattern to use
      # @param params [Hash] Parameters to substitute into the pattern
      # @return [String] The constructed URI with parameters applied
      # @raise [KeyError] If a required parameter is missing
      def construct(pattern, params)
        blueprint = find_by_pattern(pattern)
        raise ArgumentError, "Unknown blueprint pattern: #{pattern}" unless blueprint

        blueprint.construct(params)
      end

      # Filter blueprints based on a given block
      #
      # @yield [blueprint] Block that determines whether to include a blueprint
      # @yieldparam blueprint [Blueprint] A blueprint from the collection
      # @yieldreturn [Boolean] true to include the blueprint, false to exclude it
      # @return [Array<Blueprint>] Blueprints that match the filter criteria
      def filter(&block)
        @blueprints.select(&block)
      end

      # Number of blueprints in the collection
      #
      # @return [Integer] The number of blueprints
      def size
        @blueprints.size
      end

      # Check if the collection contains a blueprint with the given pattern
      #
      # @param pattern [String] The blueprint pattern to check for
      # @return [Boolean] true if a blueprint with the pattern exists
      def contains?(pattern)
        @blueprints.any? { |blueprint| blueprint.pattern == pattern }
      end

      # Group blueprints by their base protocol
      #
      # @return [Hash<String, Array<Blueprint>>] Hash mapping protocols to arrays of blueprints
      def group_by_protocol
        @blueprints.group_by(&:protocol)
      end

      # Implements enumerable functionality for the collection
      include Enumerable

      # Yield each blueprint in the collection to the given block
      #
      # @yield [blueprint] Block to execute for each blueprint
      # @yieldparam blueprint [Blueprint] A blueprint from the collection
      # @return [Enumerator] If no block is given
      def each(&block)
        @blueprints.each(&block)
      end

      # Internal Blueprint class to represent individual URI templates
      class ResourceTemplate
        attr_reader :pattern, :name, :description, :mime_type

        # Initialize a new ResourceTemplate instance
        #
        # @param data [Hash] ResourceTemplate definition hash containing uriTemplate, name, description,
        #   and optionally mimeType
        def initialize(data)
          @pattern = data["uriTemplate"]
          @name = data["name"]
          @description = data["description"]
          @mime_type = data["mimeType"]
          @variable_pattern = /{([^}]+)}/
        end

        # Extract variable names from the template pattern
        #
        # @return [Array<String>] List of variable names in the pattern
        def variables
          @pattern.scan(@variable_pattern).flatten
        end

        # Get the protocol part of the URI template
        #
        # @return [String] The protocol (scheme) of the URI template
        def protocol
          @pattern.split("://").first
        end

        # Construct a concrete URI by substituting parameters into the template pattern
        #
        # @param params [Hash] Parameters to substitute into the pattern
        # @return [String] The constructed URI with parameters applied
        # @raise [KeyError] If a required parameter is missing
        def construct(params)
          result = @pattern.dup

          variables.each do |var|
            raise KeyError, "Missing required parameter: #{var}" unless params.key?(var.to_sym) || params.key?(var)

            value = params[var.to_sym] || params[var]
            result.gsub!("{#{var}}", value.to_s)
          end

          result
        end

        # Check if this template is compatible with a set of parameters
        #
        # @param params [Hash] Parameters to check
        # @return [Boolean] true if all required variables have corresponding parameters
        def compatible_with?(params)
          symbolized_params = params.transform_keys(&:to_sym)
          variables.all? { |var| symbolized_params.key?(var.to_sym) }
        end

        # Generate a hash representation of the blueprint
        #
        # @return [Hash] Hash containing blueprint details
        def to_h
          {
            "uriTemplate" => @pattern,
            "name" => @name,
            "description" => @description,
            "mimeType" => @mime_type
          }
        end
      end
    end
  end
end

# frozen_string_literal: true

require "action_mcp/types/float_array_type"

module ActionMCP
  # Base class for defining tools.
  #
  # Provides a DSL for specifying metadata, properties, and nested collection schemas.
  # Tools are registered automatically in the ToolsRegistry unless marked as abstract.
  class Tool < Capability
    include ActionMCP::Callbacks
    include ActionMCP::CurrentHelpers

    # --------------------------------------------------------------------------
    # Class Attributes for Tool Metadata and Schema
    # --------------------------------------------------------------------------
    # @!attribute _schema_properties
    #   @return [Hash] The schema properties of the tool.
    # @!attribute _required_properties
    #   @return [Array<String>] The required properties of the tool.
    class_attribute :_schema_properties, instance_accessor: false, default: {}
    class_attribute :_required_properties, instance_accessor: false, default: []
    class_attribute :_annotations, instance_accessor: false, default: {}
    class_attribute :_output_schema, instance_accessor: false, default: nil
    class_attribute :_meta, instance_accessor: false, default: {}
    class_attribute :_requires_consent, instance_accessor: false, default: false
    class_attribute :_output_schema_builder, instance_accessor: false, default: nil

    # --------------------------------------------------------------------------
    # Tool Name and Description DSL
    # --------------------------------------------------------------------------
    # Sets or retrieves the tool's name.
    #
    # @param name [String, nil] Optional. The name to set for the tool.
    # @return [String] The current tool name.
    def self.tool_name(name = nil)
      if name
        self._capability_name = name
      else
        _capability_name || default_tool_name
      end
    end

    # Returns a default tool name based on the class name.
    #
    # @return [String] The default tool name.
    def self.default_tool_name
      return "" if name.nil?

      name.demodulize.underscore.sub(/_tool$/, "")
    end

    class << self
      alias default_capability_name default_tool_name

      def type
        :tool
      end

      def unregister_from_registry
        ActionMCP::ToolsRegistry.unregister(self) if ActionMCP::ToolsRegistry.items.values.include?(self)
      end

      # Hook called when a class inherits from Tool
      def inherited(subclass)
        super
        # Run the ActiveSupport load hook when a tool is defined
        subclass.class_eval do
          ActiveSupport.run_load_hooks(:action_mcp_tool, subclass)
        end
      end

      def annotate(key, value)
        self._annotations = _annotations.merge(key.to_s => value)
      end

      # Convenience methods for common annotations
      def title(value = nil)
        if value
          annotate(:title, value)
        else
          _annotations["title"]
        end
      end

      def destructive(enabled = true)
        annotate(:destructiveHint, enabled)
      end

      def read_only(enabled = true)
        annotate(:readOnlyHint, enabled)
      end

      def idempotent(enabled = true)
        annotate(:idempotentHint, enabled)
      end

      def open_world(enabled = true)
        annotate(:openWorldHint, enabled)
      end

      # Return annotations for the tool
      def annotations_for_protocol(_protocol_version = nil)
        # Always include annotations now that we only support 2025+
        _annotations
      end

      # Class method to call the tool with arguments
      def call(arguments = {})
        new(arguments).call
      end

      # Helper methods for checking annotations
      def read_only?
        _annotations["readOnlyHint"] == true
      end

      def idempotent?
        _annotations["idempotentHint"] == true
      end

      def destructive?
        _annotations["destructiveHint"] == true
      end

      def open_world?
        _annotations["openWorldHint"] == true
      end


      # Schema DSL for output structure
      # @param block [Proc] Block containing output schema definition
      # @return [Hash] The generated JSON Schema
      def output_schema(&block)
        return _output_schema unless block_given?

        builder = OutputSchemaBuilder.new
        builder.instance_eval(&block)

        # Store both the builder and the generated schema
        self._output_schema_builder = builder
        self._output_schema = builder.to_json_schema

        _output_schema
      end

      # Legacy output_schema method for backward compatibility
      def output_schema_legacy(schema = nil)
        if schema
          raise NotImplementedError, "Legacy output schema not yet implemented. Use output_schema DSL instead!"
        end

        _output_schema
      end

      # Sets or retrieves the _meta field
      def meta(data = nil)
        if data
          raise ArgumentError, "_meta must be a hash" unless data.is_a?(Hash)

          self._meta = _meta.merge(data)
        else
          _meta
        end
      end

      # Marks this tool as requiring consent before execution
      def requires_consent!
        self._requires_consent = true
      end

      # Returns whether this tool requires consent
      def requires_consent?
        _requires_consent
      end
    end

    # --------------------------------------------------------------------------
    # Property DSL (Direct Declaration)
    # --------------------------------------------------------------------------
    # Defines a property for the tool.
    #
    # This method builds a JSON Schema definition for the property, registers it
    # in the tool's schema, and creates an ActiveModel attribute for it.
    #
    # @param prop_name [Symbol, String] The property name.
    # @param type [String] The JSON Schema type (default: "string").
    # @param description [String, nil] Optional description for the property.
    # @param required [Boolean] Whether the property is required (default: false).
    # @param default [Object, nil] The default value for the property.
    # @param opts [Hash] Additional options for the JSON Schema.
    # @return [void]
    def self.property(prop_name, type: "string", description: nil, required: false, default: nil, **opts)
      # Build the JSON Schema definition.
      prop_definition = { type: type }
      prop_definition[:description] = description if description && !description.empty?
      prop_definition.merge!(opts) if opts.any?

      self._schema_properties = _schema_properties.merge(prop_name.to_s => prop_definition)
      self._required_properties = _required_properties.dup.tap do |req|
        req << prop_name.to_s if required
      end

      # Map the JSON Schema type to an ActiveModel attribute type.
      attribute prop_name, map_json_type_to_active_model_type(type), default: default
      validates prop_name, presence: true, if: -> { required }

      return unless %w[number integer].include?(type)

      validates prop_name, numericality: true, allow_nil: !required
    end

    # --------------------------------------------------------------------------
    # Collection DSL
    # --------------------------------------------------------------------------
    # Defines a collection property for the tool.
    #
    # @param prop_name [Symbol, String] The collection property name.
    # @param type [String] The type for collection items.
    # @param description [String, nil] Optional description for the collection.
    # @param required [Boolean] Whether the collection is required (default: false).
    # @param default [Array, nil] The default value for the collection.
    # @return [void]
    def self.collection(prop_name, type:, description: nil, required: false, default: [])
      raise ArgumentError, "Type is required for a collection" if type.nil?

      collection_definition = { type: "array", items: { type: type } }
      collection_definition[:description] = description if description && !description.empty?

      self._schema_properties = _schema_properties.merge(prop_name.to_s => collection_definition)
      self._required_properties = _required_properties.dup.tap do |req|
        req << prop_name.to_s if required
      end

      # Map the type - for number arrays, use our custom type instance
      mapped_type = if type == "number"
                      Types::FloatArrayType.new
      else
                      map_json_type_to_active_model_type("array_#{type}")
      end

      attribute prop_name, mapped_type, default: default

      # For arrays, we need to check if the attribute is nil, not if it's empty
      return unless required

      validates prop_name, presence: true, unless: -> { send(prop_name).is_a?(Array) }
      validate do
        errors.add(prop_name, "can't be blank") if send(prop_name).nil?
      end
    end

    # --------------------------------------------------------------------------
    # Tool Definition Serialization
    # --------------------------------------------------------------------------
    # Returns a hash representation of the tool definition including its JSON Schema.
    #
    # @return [Hash] The tool definition.
    def self.to_h(protocol_version: nil)
      schema = {
        type: "object",
        properties: _schema_properties
      }
      schema[:required] = _required_properties if _required_properties.any?

      result = {
        name: tool_name,
        description: description.presence,
        inputSchema: schema
      }.compact

      # Add output schema if defined
      result[:outputSchema] = _output_schema if _output_schema.present?

      # Add annotations if protocol supports them
      annotations = annotations_for_protocol(protocol_version)
      result[:annotations] = annotations if annotations.any?

      # Add _meta if present
      result[:_meta] = _meta if _meta.any?

      result
    end

    # --------------------------------------------------------------------------
    # Instance Methods
    # --------------------------------------------------------------------------

    # Override initialize to validate parameters before ActiveModel conversion
    def initialize(attributes = {})
      # Validate parameters before ActiveModel processes them
      validate_parameter_types(attributes)
      super
    end

    # Public entry point for executing the tool
    # Returns an array of Content objects collected from render calls
    def call
      @response = ToolResponse.new
      performed = false            # ← track execution

      if valid?
        begin
          run_callbacks :perform do
            performed = true       # ← set if we reach the block
            perform
          end
        rescue StandardError => e
          # Show generic error message for HTTP requests, detailed for direct calls
          error_message = if execution_context[:request].present?
                            "An unexpected error occurred."
          else
                            e.message
          end
          @response.mark_as_error!(:internal_error, message: error_message)
        end
      else
        @response.mark_as_error!(:invalid_params,
                                 message: "Invalid input",
                                 data: errors.full_messages)
      end

      # If callbacks halted execution (`performed` still false) and
      # nothing else marked an error, surface it as invalid_params.
      if !performed && !@response.error?
        @response.mark_as_error!(:invalid_params, message: "Tool execution was aborted")
      end

      @response
    end

    def inspect
      attributes_hash = attributes.transform_values(&:inspect)

      response_info = if defined?(@response) && @response
                        "response: #{@response.contents.size} content(s), isError: #{@response.is_error}"
      else
                        "response: nil"
      end

      errors_info = errors.any? ? ", errors: #{errors.full_messages}" : ""

      "#<#{self.class.name} #{attributes_hash.map do |k, v|
        "#{k}: #{v.inspect}"
      end.join(', ')}, #{response_info}#{errors_info}>"
    end

    # Override render to collect Content objects and support structured content
    def render(structured: nil, **args)
      if structured
        # Render structured content
        set_structured_content(structured)
        structured
      else
        # Normal content rendering
        content = super(**args) # Call Renderable's render method
        @response.add(content)  # Add to the response
        content # Return the content for potential use in perform
      end
    end

    # Override render_resource_link to collect ResourceLink objects
    def render_resource_link(**args)
      content = super(**args) # Call Renderable's render_resource_link method
      @response.add(content)  # Add to the response
      content # Return the content for potential use in perform
    end

    protected

    # Abstract method for subclasses to implement their logic
    # Expected to use render to produce Content objects
    def perform
      raise NotImplementedError, "Subclasses must implement the perform method"
    end

    private

    # Helper method for tools to manually report errors
    def report_error(message)
      @response.mark_as_error!
      render text: message
    end

    # Helper method to set structured content
    def set_structured_content(content)
      return unless @response

      @response.set_structured_content(content)
    end

    private


    # Maps a JSON Schema type to an ActiveModel attribute type.
    #
    # @param type [String] The JSON Schema type.
    # @return [Symbol] The corresponding ActiveModel attribute type.
    def self.map_json_type_to_active_model_type(type)
      case type.to_s
      when "number" then :float # JSON Schema "number" is a float in Ruby, the spec doesn't have an integer type yet.
      when "array_number" then :float_array
      when "array_integer" then :integer_array
      when "array_string" then :string_array
      else :string
      end
    end

    private_class_method :map_json_type_to_active_model_type

    private

    # Validates parameter types before ActiveModel conversion
    def validate_parameter_types(attributes)
      return unless attributes.is_a?(Hash)

      attributes.each do |key, value|
        key_str = key.to_s
        property_schema = self.class._schema_properties[key_str]

        next unless property_schema

        expected_type = property_schema[:type]

        # Skip validation if value is nil and property is not required
        next if value.nil? && !self.class._required_properties.include?(key_str)

        # Validate based on expected JSON Schema type
        case expected_type
        when "number"
          validate_number_parameter(key_str, value)
        when "integer"
          validate_integer_parameter(key_str, value)
        when "string"
          validate_string_parameter(key_str, value)
        when "boolean"
          validate_boolean_parameter(key_str, value)
        when "array"
          validate_array_parameter(key_str, value, property_schema)
        end
      end
    end

    def validate_number_parameter(key, value)
      return if value.is_a?(Numeric)

      raise ArgumentError, "Parameter '#{key}' must be a number, got: #{value.class}" unless value.is_a?(String)

      # Check if string can be converted to a valid number
      begin
        Float(value)
      rescue ArgumentError, TypeError
        raise ArgumentError, "Parameter '#{key}' must be a valid number, got: #{value.inspect}"
      end
    end

    def validate_integer_parameter(key, value)
      return if value.is_a?(Integer)

      raise ArgumentError, "Parameter '#{key}' must be an integer, got: #{value.class}" unless value.is_a?(String)

      # Check if string can be converted to a valid integer
      begin
        Integer(value)
      rescue ArgumentError, TypeError
        raise ArgumentError, "Parameter '#{key}' must be a valid integer, got: #{value.inspect}"
      end
    end

    def validate_string_parameter(key, value)
      return if value.is_a?(String)

      raise ArgumentError, "Parameter '#{key}' must be a string, got: #{value.class}"
    end

    def validate_boolean_parameter(key, value)
      return if value.is_a?(TrueClass) || value.is_a?(FalseClass)

      raise ArgumentError, "Parameter '#{key}' must be a boolean, got: #{value.class}"
    end

    def validate_array_parameter(key, value, _property_schema)
      return if value.is_a?(Array)

      raise ArgumentError, "Parameter '#{key}' must be an array, got: #{value.class}"
    end
  end
end

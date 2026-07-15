# frozen_string_literal: true

require "action_mcp/types/float_array_type"
require "action_mcp/types/hash_type"
require "action_mcp/schema_helpers"
require "action_mcp/schema_validator"

module ActionMCP
  # Base class for defining tools.
  #
  # Provides a DSL for specifying metadata, properties, and nested collection schemas.
  # Tools are registered automatically in the ToolsRegistry unless marked as abstract.
  class Tool < Capability
    include ActionMCP::Callbacks
    include ActionMCP::CurrentHelpers
    extend ActionMCP::SchemaHelpers

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
    class_attribute :_additional_properties, instance_accessor: false, default: false
    class_attribute :_cached_schema_property_keys, instance_accessor: false, default: nil
    class_attribute :_input_schemer, instance_accessor: false, default: nil
    class_attribute :_output_schemer, instance_accessor: false, default: nil
    class_attribute :_property_aliases, instance_accessor: false, default: {}
    class_attribute :_task_support, instance_accessor: false, default: :forbidden
    class_attribute :_resumable_steps_block, instance_accessor: false, default: nil

    validate :input_arguments_match_schema

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
        re_register_if_needed
        name
      else
        _capability_name || default_tool_name
      end
    end

    # Re-registers the tool if it was already registered under a different name
    # @return [void]
    def self.re_register_if_needed
      return if abstract?
      return unless _registered_name # Not yet registered

      new_name = capability_name
      return if _registered_name == new_name # No change

      ActionMCP::ToolsRegistry.re_register(self, _registered_name)
    end

    private_class_method :re_register_if_needed

    # Returns a default tool name based on the class name.
    #
    # @return [String] The default tool name.
    def self.default_tool_name
      return "" if name.nil?

      name.underscore.gsub("/", "__").sub(/_tool$/, "")
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
        from_wire(arguments).call
      end

      # Builds a tool from decoded MCP arguments. The untouched input is kept
      # for JSON Schema validation before ActiveModel coercion.
      def from_wire(arguments)
        new(arguments).tap do |tool|
          tool.instance_variable_set(:@_wire_arguments, arguments)
        end
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
        schema = builder.to_json_schema
        schemer = SchemaValidator.compile(schema, context: "output schema for #{tool_name}")

        self._output_schema_builder = builder
        self._output_schema = schema
        self._output_schemer = schemer

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

      # Declares the UI resource this tool renders. Merges a `ui:` entry into
      # `_meta` so the tool listing advertises the dashboard.
      #
      # @param resource_uri [String] a `ui://` URI
      # @param visibility [Array<Symbol, String>, nil] subset of `[:model, :app]`
      def renders_ui(resource_uri, visibility: nil)
        unless resource_uri.is_a?(String) && Apps::URI_SCHEME.match?(resource_uri)
          raise ArgumentError, "renders_ui requires a ui:// URI, got: #{resource_uri.inspect}"
        end

        normalized_visibility =
          if visibility
            normalized = Array(visibility).map(&:to_s)
            invalid = normalized - Apps::VISIBILITY_VALUES
            if invalid.any?
              raise ArgumentError,
                    "renders_ui visibility must be #{Apps::VISIBILITY_VALUES.join('/')}, got: #{visibility.inspect}"
            end
            normalized
          end

        ui_meta = { resourceUri: resource_uri, visibility: normalized_visibility }.compact
        self._meta = _meta.deep_merge(ui: ui_meta)
      end

      # Marks this tool as requiring consent before execution
      def requires_consent!
        self._requires_consent = true
      end

      # Returns whether this tool requires consent
      def requires_consent?
        _requires_consent
      end

      # --------------------------------------------------------------------------
      # Task Support DSL (MCP 2025-11-25)
      # --------------------------------------------------------------------------
      # Sets or retrieves the task support mode for this tool
      # @param mode [Symbol, nil] :required, :optional, or :forbidden (default)
      # @return [Symbol] The current task support mode
      def task_support(mode = nil)
        if mode
          unless %i[required optional forbidden].include?(mode)
            raise ArgumentError, "task_support must be :required, :optional, or :forbidden"
          end

          self._task_support = mode
        else
          _task_support
        end
      end

      # Convenience methods for task support
      def task_required!
        self._task_support = :required
      end

      def task_optional!
        self._task_support = :optional
      end

      def task_forbidden!
        self._task_support = :forbidden
      end

      # Returns the execution metadata including task support
      def execution_metadata
        {
          taskSupport: _task_support.to_s
        }
      end

      # --------------------------------------------------------------------------
      # Resumable Steps DSL (ActiveJob::Continuable support)
      # --------------------------------------------------------------------------
      # Defines resumable execution steps for long-running tools
      # @param block [Proc] Block containing step definitions
      # @return [void]
      def resumable_steps(&block)
        self._resumable_steps_block = block
      end

      # Checks if tool has resumable steps defined
      # @return [Boolean]
      def resumable_steps_defined?
        _resumable_steps_block.present?
      end

      # Sets or retrieves the additionalProperties setting for the input schema
      # @param enabled [Boolean, Hash] true to allow any additional properties,
      #   false to disallow them, or a Hash for typed additional properties
      def additional_properties(enabled = nil)
        if enabled.nil?
          _additional_properties
        else
          unless enabled == true || enabled == false || enabled.is_a?(Hash)
            raise ArgumentError, "additional_properties must be true, false, or a JSON Schema hash"
          end

          self._additional_properties = enabled
          invalidate_schema_cache
        end
      end

      # Returns whether this tool accepts additional properties
      def accepts_additional_properties?
        !_additional_properties.nil? && _additional_properties != false
      end

      # Returns cached string keys for schema properties to avoid repeated conversions
      def schema_property_keys
        return _cached_schema_property_keys if _cached_schema_property_keys

        self._cached_schema_property_keys = (_schema_properties.keys + _property_aliases.keys).map(&:to_s)
        _cached_schema_property_keys
      end

      def input_schema
        properties = _schema_properties.deep_dup
        _property_aliases.each do |alias_name, property_name|
          properties[alias_name] = _schema_properties.fetch(property_name).deep_dup
        end

        schema = {
          "$schema" => SchemaValidator::DEFAULT_DIALECT,
          type: "object",
          properties: properties
        }

        required = []
        alias_constraints = []
        _required_properties.each do |property_name|
          aliases = _property_aliases.select { |_alias_name, target| target == property_name }.keys
          if aliases.empty?
            required << property_name
          else
            alternatives = [ property_name, *aliases ].map { |name| { required: [ name ] } }
            alias_constraints << { anyOf: alternatives }
          end
        end

        schema[:required] = required if required.any?
        schema[:allOf] = alias_constraints if alias_constraints.any?
        add_additional_properties_to_schema(schema, _additional_properties)
        schema
      end

      def input_schemer
        self._input_schemer ||= SchemaValidator.compile(input_schema, context: "input schema for #{tool_name}")
      end

      def output_schemer
        return unless _output_schema

        self._output_schemer ||= SchemaValidator.compile(_output_schema, context: "output schema for #{tool_name}")
      end

      # Creates an alternate input name for an existing property.
      #
      # @example
      #   property :thread_id, type: "string", required: true
      #   alias_property :root_id, :thread_id
      #
      # Both `root_id` and `thread_id` are accepted when initializing the tool,
      # and both readers resolve to the same ActiveModel attribute.
      def alias_property(alias_name, property_name)
        alias_key = alias_name.to_s
        property_key = canonical_property_name(property_name)

        unless _schema_properties.key?(property_key)
          raise ArgumentError, "Cannot alias unknown property '#{property_name}'"
        end

        if alias_key == property_key
          raise ArgumentError, "Cannot alias property '#{property_key}' to itself"
        end

        if _schema_properties.key?(alias_key)
          raise ArgumentError, "Cannot alias '#{alias_key}' because it is already defined as a property"
        end

        existing_alias = _property_aliases[alias_key]
        if existing_alias && existing_alias != property_key
          raise ArgumentError, "Alias '#{alias_key}' already points to property '#{existing_alias}'"
        end

        self._property_aliases = _property_aliases.merge(alias_key => property_key)
        alias_attribute alias_key, property_key
        invalidate_schema_cache
      end

      def canonical_property_name(name)
        _property_aliases[name.to_s] || name.to_s
      end

      private

      # Invalidate cached schema property keys
      def invalidate_schema_cache
        self._cached_schema_property_keys = nil
        self._input_schemer = nil
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
      if _property_aliases.key?(prop_name.to_s)
        raise ArgumentError, "Cannot define property '#{prop_name}' because it is already defined as an alias"
      end

      invalidate_schema_cache

      # Build the JSON Schema definition.
      prop_definition = { type: type }
      prop_definition[:description] = description if description && !description.empty?
      prop_definition.merge!(opts) if opts.any?

      self._schema_properties = _schema_properties.merge(prop_name.to_s => prop_definition)
      new_required = _required_properties.dup
      new_required << prop_name.to_s if required
      self._required_properties = new_required

      # Map the JSON Schema type to an ActiveModel attribute type.
      attribute prop_name, map_json_type_to_active_model_type(type), default: default
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

      if _property_aliases.key?(prop_name.to_s)
        raise ArgumentError, "Cannot define collection '#{prop_name}' because it is already defined as an alias"
      end

      invalidate_schema_cache

      collection_definition = { type: "array", items: { type: type } }
      collection_definition[:description] = description if description && !description.empty?

      self._schema_properties = _schema_properties.merge(prop_name.to_s => collection_definition)
      new_required = _required_properties.dup
      new_required << prop_name.to_s if required
      self._required_properties = new_required

      # Map the type - for number arrays, use our custom type instance
      mapped_type = if type == "number"
                      Types::FloatArrayType.new
      else
                      map_json_type_to_active_model_type("array_#{type}")
      end

      attribute prop_name, mapped_type, default: default
    end

    # --------------------------------------------------------------------------
    # Tool Definition Serialization
    # --------------------------------------------------------------------------
    # Returns a hash representation of the tool definition including its JSON Schema.
    #
    # @return [Hash] The tool definition.
    def self.to_h(protocol_version: nil)
      schema = input_schema
      input_schemer

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

      # Add execution metadata (MCP 2025-11-25)
      # Only include if not default (forbidden) to minimize payload
      if _task_support && _task_support != :forbidden
        result[:execution] = execution_metadata
      end

      # Add _meta if present
      if _meta.any?
        resolved_meta = _meta.deep_dup
        ui_meta = resolved_meta[:ui] || resolved_meta["ui"]
        if ui_meta.is_a?(Hash)
          resource_uri_key = :resourceUri if ui_meta.key?(:resourceUri)
          resource_uri_key ||= "resourceUri" if ui_meta.key?("resourceUri")
          if resource_uri_key
            ui_meta[resource_uri_key] = Apps::ViewManifest.resolve_resource_uri(ui_meta[resource_uri_key])
          end
        end
        result[:_meta] = resolved_meta
      end

      result
    end

    # --------------------------------------------------------------------------
    # Instance Methods
    # --------------------------------------------------------------------------

    def initialize(attributes = {})
      @_alias_conflicts = []

      defined_attributes = {}
      additional_attributes = {}

      if attributes.is_a?(Hash)
        sources = {}
        attributes.each do |key, value|
          key_string = key.to_s
          property_name = self.class.canonical_property_name(key_string)

          if self.class._schema_properties.key?(property_name)
            if defined_attributes.key?(property_name) && sources[property_name] != key_string &&
                defined_attributes[property_name] != value
              @_alias_conflicts <<
                "conflicting values for '#{property_name}' via '#{sources[property_name]}' and '#{key_string}'"
              next
            end

            defined_attributes[property_name] = value
            sources[property_name] = key_string
          else
            additional_attributes[key] = value
          end
        end
      end

      @_provided_additional_attributes = additional_attributes
      @_additional_params = self.class.accepts_additional_properties? ? additional_attributes : {}
      super(defined_attributes)
    end

    # Returns additional parameters that were passed but not defined in the schema
    def additional_params
      @_additional_params || {}
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
          @response.report_tool_error(error_message)
        end
      else
        @response.report_tool_error("Invalid input: #{errors.full_messages.join(', ')}")
      end

      # If callbacks halted execution (`performed` still false) and
      # nothing else marked an error, surface it as a tool execution error.
      if !performed && !@response.error?
        @response.report_tool_error("Tool execution was aborted")
      end

      if performed && !@response.error? && self.class._output_schema && @response.structured_content.nil?
        @response.report_tool_error("Tool declared an output schema but returned no structured content")
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
      unless structured.nil?
        validate_structured_content!(structured) if self.class._output_schema

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

    # Request user/client input and pause execution
    # @param prompt [String] The prompt/question for the user
    # @param context [Hash] Additional context about the input request
    # @return [void]
    def request_input!(prompt:, context: {})
      @_input_required = { prompt: prompt, context: context }
      throw :halt_execution # Use throw to exit perform block
    end

    # Report progress for long-running tool operations
    # Only available when tool is running in task-augmented mode
    # @param percent [Integer] Progress percentage (0-100)
    # @param message [String] Optional progress message
    # @param cursor [Integer, String] Optional cursor for iteration state
    # @return [void]
    def report_progress!(percent:, message: nil, cursor: nil)
      return unless @_task # Only available in task-augmented mode

      @_task.update_progress!(percent: percent, message: message)
      @_task.record_step!(:in_progress, cursor: cursor) if cursor
    end

    private

    # Helper method for tools to manually report errors
    # Uses the MCP-compliant tool execution error format
    def report_error(message)
      @response.report_tool_error(message)
    end

    # Helper method to set structured content
    def set_structured_content(content)
      return unless @response

      @response.set_structured_content(content)
    end

    def input_arguments_match_schema
      validation_input = if defined?(@_wire_arguments)
                           @_wire_arguments
      else
                           attributes.compact.merge(@_provided_additional_attributes.deep_stringify_keys)
      end
      schema_errors = SchemaValidator.validate(self.class.input_schemer, validation_input)
      SchemaValidator.error_messages(schema_errors).each { |message| errors.add(:base, message) }
      @_alias_conflicts.each { |message| errors.add(:base, message) }
    end

    # Validates structured content against the declared output_schema.
    # @param content [Hash] The structured content to validate
    # @raise [StructuredContentValidationError] If content doesn't match schema
    def validate_structured_content!(content)
      schema_errors = SchemaValidator.validate(self.class.output_schemer, content)
      return if schema_errors.empty?

      raise ActionMCP::StructuredContentValidationError,
            "Structured content does not match output_schema: " \
            "#{SchemaValidator.error_messages(schema_errors).join(', ')}"
    end

    # Maps a JSON Schema type to an ActiveModel attribute type.
    #
    # @param type [String] The JSON Schema type.
    # @return [Symbol] The corresponding ActiveModel attribute type.
    def self.map_json_type_to_active_model_type(type)
      case type.to_s
      when "number"        then :float # JSON Schema "number" maps to float; no distinct integer type in JSON Schema number.
      when "integer"       then :integer
      when "boolean"       then :boolean
      when "object"        then Types::HashType.new
      when "array_number"  then :float_array
      when "array_integer" then :integer_array
      when "array_string"  then :string_array
      else :string
      end
    end

    private_class_method :map_json_type_to_active_model_type
  end
end

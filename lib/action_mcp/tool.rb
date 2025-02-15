# frozen_string_literal: true

module ActionMCP
  # Base class for defining tools.
  #
  # Provides a DSL for specifying metadata, properties, and nested collection schemas.
  # Tools are registered automatically in the ToolsRegistry unless marked as abstract.
  class Tool
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Renderable

    # --------------------------------------------------------------------------
    # Class Attributes for Tool Metadata and Schema
    # --------------------------------------------------------------------------
    class_attribute :_tool_name, instance_accessor: false
    class_attribute :_description, instance_accessor: false, default: ""
    class_attribute :_schema_properties, instance_accessor: false, default: {}
    class_attribute :_required_properties, instance_accessor: false, default: []
    class_attribute :abstract_tool, instance_accessor: false, default: false

    # --------------------------------------------------------------------------
    # Subclass Registration
    # --------------------------------------------------------------------------
    # Automatically registers non-abstract subclasses in the ToolsRegistry.
    #
    # @param subclass [Class] the subclass inheriting from Tool.
    def self.inherited(subclass)
      super
      return if subclass == Tool

      subclass.abstract_tool = false
      return if subclass.name == "ApplicationTool"

      ToolsRegistry.register(subclass.tool_name, subclass)
    end

    # Marks this tool as abstract so that it won’t be available for use.
    # If the tool is registered in ToolsRegistry, it is unregistered.
    def self.abstract!
      self.abstract_tool = true
      ToolsRegistry.unregister(tool_name) if ToolsRegistry.items.key?(tool_name)
    end

    # Returns whether this tool is abstract.
    #
    # @return [Boolean] true if abstract, false otherwise.
    def self.abstract?
      abstract_tool
    end

    # --------------------------------------------------------------------------
    # Tool Name and Description DSL
    # --------------------------------------------------------------------------
    # Sets or retrieves the tool's name.
    #
    # @param name [String, nil] Optional. The name to set for the tool.
    # @return [String] The current tool name.
    def self.tool_name(name = nil)
      if name
        self._tool_name = name
      else
        _tool_name || default_tool_name
      end
    end

    # Returns a default tool name based on the class name.
    #
    # @return [String] The default tool name.
    def self.default_tool_name
      name.demodulize.underscore.dasherize.sub(/-tool$/, "")
    end

    # Sets or retrieves the tool's description.
    #
    # @param text [String, nil] Optional. The description text to set.
    # @return [String] The current description.
    def self.description(text = nil)
      if text
        self._description = text
      else
        _description
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

      validates prop_name, numericality: true
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
    def self.collection(prop_name, type:, description: nil, required: false, default: [])
      raise ArgumentError, "Type is required for a collection" if type.nil?

      collection_definition = { type: "array", description: description, items: { type: type } }

      self._schema_properties = _schema_properties.merge(prop_name.to_s => collection_definition)
      self._required_properties = _required_properties.dup.tap do |req|
        req << prop_name.to_s if required
      end

      type = map_json_type_to_active_model_type("array_#{type}")
      attribute prop_name, type, default: default
      validates prop_name, presence: true, if: -> { required }
    end

    # --------------------------------------------------------------------------
    # Tool Definition Serialization
    # --------------------------------------------------------------------------
    # Returns a hash representation of the tool definition including its JSON Schema.
    #
    # @return [Hash] The tool definition.
    def self.to_h
      schema = { type: "object", properties: _schema_properties }
      schema[:required] = _required_properties if _required_properties.any?
      {
        name: tool_name,
        description: description.presence,
        inputSchema: schema
      }.compact
    end

    # --------------------------------------------------------------------------
    # Instance Methods
    # --------------------------------------------------------------------------
    # Abstract method to perform the tool's action.
    #
    # Subclasses must implement this method.
    #
    # @raise [NotImplementedError] Always raised if not implemented in a subclass.
    def call
      raise NotImplementedError, "Subclasses must implement the call method"
      # Default implementation (no-op)
      # In a real subclass, you might do:
      #   def call
      #     # Perform logic, e.g. analyze code, etc.
      #     # Array of Content objects is expected as return value
      #   end
    end

    private

    # Maps a JSON Schema type to an ActiveModel attribute type.
    #
    # @param type [String] The JSON Schema type.
    # @return [Symbol] The corresponding ActiveModel attribute type.
    def self.map_json_type_to_active_model_type(type)
      case type.to_s
      when "number" then  :float # JSON Schema "number" is a float in Ruby, the spec doesn't have an integer type yet.
      when "array_number" then :integer_array
      when "array_integer" then :string_array
      when "array_string" then :string_array
      else                :string
      end
    end
    private_class_method :map_json_type_to_active_model_type
  end
end

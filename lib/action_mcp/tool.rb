# lib/action_mcp/tool.rb
# frozen_string_literal: true

module ActionMCP
  class Tool
    include ActiveModel::Model
    include ActiveModel::Attributes

    class_attribute :_tool_name, instance_accessor: false
    class_attribute :_description, instance_accessor: false, default: ""
    class_attribute :_schema_properties, instance_accessor: false, default: {}
    class_attribute :_required_properties, instance_accessor: false, default: []
    class_attribute :abstract_tool, instance_accessor: false, default: false

    # Register each non-abstract subclass in ToolsRegistry
    def self.inherited(subclass)
      super
      return if subclass == Tool

      subclass.abstract_tool = false
      return if subclass.name == "ApplicationTool"

      ToolsRegistry.register(subclass.tool_name, subclass)
    end

    # Mark this tool as abstract so it won’t be available for use.
    def self.abstract!
      self.abstract_tool = true
      ToolsRegistry.unregister(tool_name) if ToolsRegistry.items.key?(tool_name)
    end

    def self.abstract?
      abstract_tool
    end

    # ---------------------------------------------------
    # Tool Name & Description
    # ---------------------------------------------------
    def self.tool_name(name = nil)
      if name
        self._tool_name = name
      else
        _tool_name || default_tool_name
      end
    end

    def self.default_tool_name
      name.demodulize.underscore.dasherize.sub(/-tool$/, "")
    end

    def self.description(text = nil)
      if text
        self._description = text
      else
        _description
      end
    end

    # ---------------------------------------------------
    # Property DSL (Direct Declaration)
    # ---------------------------------------------------
    def self.property(prop_name, type: "string", description: nil, required: false, default: nil, **opts)
      # Build JSON Schema definition for the property.
      prop_definition = { type: type }
      prop_definition[:description] = description if description && !description.empty?
      prop_definition.merge!(opts) if opts.any?

      self._schema_properties = _schema_properties.merge(prop_name.to_s => prop_definition)
      self._required_properties = _required_properties.dup
      _required_properties << prop_name.to_s if required

      # Map our DSL type to an ActiveModel attribute type.
      am_type = case type.to_s
      when "number" then :float
      when "integer" then :integer
      when "array"   then :string
      else
                  :string
      end
      attribute prop_name, am_type, default: default
    end

    # ---------------------------------------------------
    # Collection DSL
    # ---------------------------------------------------
    # Supports two forms:
    #
    # 1. Without a block:
    #    collection :args, type: "string", description: "Command arguments"
    #
    # 2. With a block (defining a nested object):
    #    collection :files, description: "List of Files" do
    #      property :file, required: true, description: 'file uri'
    #      property :checksum, required: true, description: 'checksum to verify'
    #    end
    def self.collection(prop_name, type: nil, description: nil, required: false, default: nil, **_opts, &block)
      if block_given?
        # Build nested schema for an object.
        nested_schema = { type: "object", properties: {}, required: [] }
        dsl = CollectionDSL.new(nested_schema)
        dsl.instance_eval(&block)
        collection_definition = { type: "array", description: description, items: nested_schema }
      else
        raise ArgumentError, "Type is required for a collection without a block" if type.nil?

        collection_definition = { type: "array", description: description, items: { type: type } }
      end

      self._schema_properties = _schema_properties.merge(prop_name.to_s => collection_definition)
      self._required_properties = _required_properties.dup
      _required_properties << prop_name.to_s if required

      # Register the property as an attribute.
      # (Mapping for a collection can be customized; here we use :string to mimic previous behavior.)
      attribute prop_name, :string, default: default
    end

    # DSL for building a nested schema within a collection block.
    class CollectionDSL
      attr_reader :schema

      def initialize(schema)
        @schema = schema
      end

      def property(prop_name, type: "string", description: nil, required: false, default: nil, **opts)
        prop_definition = { type: type }
        prop_definition[:description] = description if description && !description.empty?
        prop_definition.merge!(opts) if opts.any?

        @schema[:properties][prop_name.to_s] = prop_definition
        @schema[:required] << prop_name.to_s if required
      end
    end

    # ---------------------------------------------------
    # Convert Tool Definition to Hash
    # ---------------------------------------------------
    def self.to_h
      schema = { type: "object", properties: _schema_properties }
      schema[:required] = _required_properties if _required_properties.any?
      {
        name: tool_name,
        description: description.presence,
        inputSchema: schema
      }.compact
    end
  end
end

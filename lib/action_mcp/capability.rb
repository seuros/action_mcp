# frozen_string_literal: true

require_relative "renderable"

module ActionMCP
  class Capability
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Callbacks
    include Instrumentation::Instrumentation
    include Renderable
    include RequestMeta

    class_attribute :_capability_name, instance_accessor: false
    class_attribute :_registered_name, instance_accessor: false
    class_attribute :_description, instance_accessor: false, default: ""
    class_attribute :_meta, instance_accessor: false, default: {}

    attr_reader :execution_context

    def initialize(*)
      super
      @execution_context = {}
    end

    def with_context(context)
      @execution_context = context
      self
    end

    def session
      execution_context[:session]
    end

    def inspect
      attribute_list = attributes.transform_values(&:inspect).map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      response_info = defined?(@response) && @response ? "response: #{response_summary}" : "response: nil"
      errors_info = errors.any? ? ", errors: #{errors.full_messages}" : ""

      "#<#{self.class.name} #{attribute_list}, #{response_info}#{errors_info}>"
    end

    delegate :session_data, to: :session, allow_nil: true

    # Returns true when the connected client advertises the MCP Apps UI extension
    # and supports ActionMCP's HTML app resource MIME type.
    def client_supports_ui?
      Apps.client_supports?(session&.client_capabilities)
    end
    alias client_supports_mcp_app? client_supports_ui?

    # use _capability_name or default_capability_name
    def self.capability_name
      _capability_name || default_capability_name
    end

    def self.abstract_capability
      @abstract_capability ||= false # Default to false, unique to each class
    end

    class << self
      attr_writer :abstract_capability
    end

    # Marks this tool as abstract so that it won’t be available for use.
    # If the tool is registered in ToolsRegistry, it is unregistered.
    #
    # @return [void]
    def self.abstract!
      self.abstract_capability = true
      # Unregister from the appropriate registry if already registered
      unregister_from_registry
    end

    # Returns whether this tool is abstract.
    #
    # @return [Boolean] true if abstract, false otherwise.
    def self.abstract?
      abstract_capability
    end

    def self.description(text = nil)
      if text
        self._description = text
      else
        _description
      end
    end

    # Sets or retrieves the _meta field
    def self.meta(data = nil)
      return _meta unless data
      raise ArgumentError, "_meta must be a hash" unless data.is_a?(Hash)

      self._meta = _meta.merge(data)
    end

    # Name derived from the class: Admin::ReportTool => "admin__report".
    def self.default_capability_name
      return "" if name.nil?

      name.underscore.gsub("/", "__").sub(/_#{type}$/, "")
    end

    def self.unregister_from_registry
      registry.unregister(self) if registry.store.values.include?(self)
    end

    def self.assign_capability_name(name)
      self._capability_name = name
      re_register_if_needed
      name
    end

    # Re-registers under the new name when the class was registered under an older one.
    def self.re_register_if_needed
      return if abstract? || !_registered_name || _registered_name == capability_name

      registry.re_register(self, _registered_name)
    end

    private_class_method :assign_capability_name, :re_register_if_needed
  end
end

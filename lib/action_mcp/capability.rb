# frozen_string_literal: true

require_relative "renderable"

module ActionMCP
  class Capability
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Renderable

    class_attribute :_capability_name, instance_accessor: false
    class_attribute :_description, instance_accessor: false, default: ""

    # use _capability_name or default_capability_name
    def self.capability_name
      _capability_name || default_capability_name
    end

    def self.abstract_capability
      @abstract_capability ||= false # Default to false, unique to each class
    end

    def self.abstract_capability=(value)
      @abstract_capability = value
    end

    # Marks this tool as abstract so that it won’t be available for use.
    # If the tool is registered in ToolsRegistry, it is unregistered.
    #
    # @return [void]
    def self.abstract!
      self.abstract_capability = true
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
  end
end

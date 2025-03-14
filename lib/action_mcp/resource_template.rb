# frozen_string_literal: true

module ActionMCP
  class ResourceTemplate
    class_attribute :abstract, instance_accessor: false, default: false

    attr_reader :description, :uri_template, :mime_type

    def self.parameter(name, description:, required: false)
      @parameters ||= {}
      @parameters[name] = { description: description, required: required }
    end

    def self.parameters
      @parameters || {}
    end

    def self.description(description = nil)
      return @description unless description
      @description = description
    end

    def self.to_h
      name_value = defined?(@template_name) ? @template_name : name.demodulize.underscore.gsub(/_template$/, '')

      {
        uriTemplate: @uri_template,
        name: name_value,
        description: @description,
        mimeType: @mime_type
      }.compact
    end

    def self.uri_template(uri_template = nil)
      return @uri_template unless uri_template
      @uri_template = uri_template
    end

    def self.template_name(name = nil)
      @template_name = name if name
      @template_name
    end

    def self.mime_type(mime_type = nil)
      return @mime_type unless mime_type
      @mime_type = mime_type
    end

    def self.retrieve(_params)
      raise NotImplementedError, "Subclasses must implement the retrieve method"
    end

    def self.abstract
      @abstract_tool ||= false # Default to false, unique to each class
    end

    def self.abstract=(value)
      @abstract_tool = value
    end

    def self.abstract!
      self.abstract = true
    end

    def self.abstract?
      abstract
    end

    def self.capability_name
      name.demodulize.underscore.sub(/_template$/, "")
    end
  end
end

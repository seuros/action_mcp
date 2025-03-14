# frozen_string_literal: true

module ActionMCP
  class ResourceTemplate
    class_attribute :abstract, instance_accessor: false, default: false

    class << self
      attr_writer :abstract
      attr_reader :description, :uri_template, :mime_type, :template_name, :parameters

      def parameter(name, description:, required: false)
        @parameters ||= {}
        @parameters[name] = { description: description, required: required }
      end

      def parameters
        @parameters || {}
      end

      def description(value = nil)
        value ? @description = value : @description
      end

      def uri_template(value = nil)
        value ? @uri_template = value : @uri_template
      end

      def template_name(value = nil)
        value ? @template_name = value : @template_name
      end

      def mime_type(value = nil)
        value ? @mime_type = value : @mime_type
      end

      def to_h
        name_value = defined?(@template_name) ? @template_name : name.demodulize.underscore.gsub(/_template$/, "")

        {
          uriTemplate: @uri_template,
          name: name_value,
          description: @description,
          mimeType: @mime_type
        }.compact
      end

      def retrieve(_params)
        raise NotImplementedError, "Subclasses must implement the retrieve method"
      end

      def abstract?
        abstract
      end

      def abstract!
        self.abstract = true
      end

      def capability_name
        name.demodulize.underscore.sub(/_template$/, "")
      end
    end

    attr_reader :description, :uri_template, :mime_type
  end
end
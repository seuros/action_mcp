# frozen_string_literal: true

require "addressable/template"

module ActionMCP
  # Registry for managing resource templates.
  class ResourceTemplatesRegistry < RegistryBase
    class << self
      # @!method resource_templates
      #   Returns all registered resource templates.
      #   @return [Hash] A hash of registered resource templates.
      alias resource_templates items

      # Retrieves a resource template by name.
      #
      # @param template_name [String] The name of the resource template to retrieve.
      # @return [ActionMCP::ResourceTemplate] The resource template.
      # @raise [RegistryBase::NotFound] if the resource template is not found.
      def get_resource_template(template_name)
        find(template_name)
      end

      def item_klass
        ResourceTemplate
      end

      # Find the most specific template for a given URI.
      # Uses registry-backed source (not ResourceTemplate.registered_templates class array).
      def find_template_for_uri(uri, templates: resource_templates.values)
        matching_templates = templates.select do |template|
          next unless template.uri_template

          compiled_template(template.uri_template).extract(uri)
        rescue Addressable::URI::InvalidURIError,
               Addressable::Template::InvalidTemplateValueError,
               Addressable::Template::InvalidTemplateOperatorError
          false
        end

        # If multiple templates match, select the most specific one
        # (the one with the most static segments)
        if matching_templates.size > 1
          matching_templates.max_by do |template|
            template_specificity(template.uri_template)
          end
        elsif matching_templates.size == 1
          matching_templates.first
        end
      end

      # Check if a URI matches a specific template
      def uri_matches_template?(uri, template)
        !compiled_template(template.uri_template).extract(uri).nil?
      rescue Addressable::URI::InvalidURIError,
             Addressable::Template::InvalidTemplateValueError,
             Addressable::Template::InvalidTemplateOperatorError
        false
      end

      # Extract parameter values from a URI based on a template
      def extract_parameters(uri, template)
        extracted = compiled_template(template.uri_template).extract(uri)
        extracted ? extracted.transform_keys(&:to_sym) : {}
      rescue Addressable::URI::InvalidURIError,
             Addressable::Template::InvalidTemplateValueError,
             Addressable::Template::InvalidTemplateOperatorError
        {}
      end

      private

      def compiled_template(pattern)
        compiled_templates[pattern] ||= Addressable::Template.new(pattern)
      end

      def compiled_templates
        @compiled_templates ||= {}
      end

      def template_specificity(pattern)
        segments = pattern.split("/")
        static_segments = segments.count { |segment| !segment.include?("{") }
        literal_length = pattern.gsub(/\{[^}]*\}/, "").length
        [ static_segments, literal_length ]
      end
    end
  end
end

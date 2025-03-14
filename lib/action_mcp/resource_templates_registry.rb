# frozen_string_literal: true

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
    end
  end
end

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

      # Find the most specific template for a given URI
      def find_template_for_uri(uri)
        parse_result = parse_uri(uri)
        return nil unless parse_result

        schema = parse_result[:schema]
        path = parse_result[:path]
        path_segments = path.split("/")

        matching_templates = ResourceTemplate.registered_templates.select do |template|
          next unless template.uri_template

          # Parse the template
          template_data = parse_uri_template(template.uri_template)
          next unless template_data && template_data[:schema] == schema

          # Split template into segments and check if structure matches
          template_segments = template_data[:path].split("/")
          next unless template_segments.length == path_segments.length

          # Check if each segment matches (either static match or a parameter)
          segments_match = true

          template_segments.each_with_index do |template_segment, index|
            path_segment = path_segments[index]

            if template_segment.start_with?("{") && template_segment.end_with?("}")
              # This is a parameter segment, it matches any value
              next
            elsif template_segment != path_segment
              # Static segment doesn't match
              segments_match = false
              break
            end
          end

          segments_match
        end

        # If multiple templates match, select the most specific one
        # (the one with the most static segments)
        if matching_templates.size > 1
          matching_templates.max_by do |template|
            template_data = parse_uri_template(template.uri_template)
            template_segments = template_data[:path].split("/")

            # Count static segments (not parameters)
            template_segments.count { |segment| !segment.start_with?("{") }
          end
        elsif matching_templates.size == 1
          matching_templates.first
        end
      end

      # Check if a URI matches a specific template
      def uri_matches_template?(uri, template)
        uri_data = parse_uri(uri)
        template_data = parse_uri_template(template.uri_template)

        return false unless uri_data && template_data && uri_data[:schema] == template_data[:schema]

        uri_segments = uri_data[:path].split("/")
        template_segments = template_data[:path].split("/")

        return false unless uri_segments.length == template_segments.length

        # Check each segment
        template_segments.each_with_index do |template_segment, index|
          uri_segment = uri_segments[index]

          # If template segment is a parameter, it matches anything
          next if template_segment.start_with?("{") && template_segment.end_with?("}")

          # Otherwise, segments must match exactly
          return false if template_segment != uri_segment
        end

        true
      end

      # Extract parameter values from a URI based on a template
      def extract_parameters(uri, template)
        return {} unless uri_matches_template?(uri, template)

        uri_data = parse_uri(uri)
        template_data = parse_uri_template(template.uri_template)

        uri_segments = uri_data[:path].split("/")
        template_segments = template_data[:path].split("/")

        # Extract parameters
        params = {}
        template_segments.each_with_index do |template_segment, index|
          next unless template_segment.start_with?("{") && template_segment.end_with?("}")

          # Extract parameter name without braces
          param_name = template_segment[1...-1].to_sym
          params[param_name] = uri_segments[index]
        end

        params
      end

      private

      # Parse a concrete URI
      def parse_uri(uri)
        return unless uri =~ %r{^([^:]+)://(.+)$}

        {
          schema: ::Regexp.last_match(1),
          path: ::Regexp.last_match(2),
          original: uri
        }
      end

      # Parse a URI template
      def parse_uri_template(template)
        return unless template =~ %r{^([^:]+)://(.+)$}

        {
          schema: ::Regexp.last_match(1),
          path: ::Regexp.last_match(2),
          original: template
        }
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class ResourceTemplate
    # Track all registered templates
    @registered_templates = []

    class << self
      attr_reader :registered_templates

      def abstract?
        @abstract ||= false
      end

      def abstract!
        @abstract = true
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@abstract, false)
      end

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
        if value
          validate_unique_uri_template(value)
          @uri_template = value
          # Only register if not abstract and uri_template is set
          ResourceTemplate.registered_templates << self unless abstract?
        else
          @uri_template
        end
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

      def capability_name
        name.demodulize.underscore.sub(/_template$/, "")
      end

      private

      # Extract the schema and pattern from a URI template
      def parse_uri_template(template)
        # Parse the URI template to get schema and pattern
        # Format: schema://path/{param1}/{param2}...
        if template =~ /^([^:]+):\/\/(.+)$/
          schema = $1
          pattern = $2

          # Replace parameter placeholders with generic markers to compare structure
          normalized_pattern = pattern.gsub(/\{[^}]+\}/, '{param}')

          return { schema: schema, pattern: normalized_pattern, original: template }
        end

        raise ArgumentError, "Invalid URI template format: #{template}"
      end

      # Validate that the URI template is unique
      def validate_unique_uri_template(new_template)
        new_template_data = parse_uri_template(new_template)

        ResourceTemplate.registered_templates.each do |registered_class|
          next if registered_class == self || registered_class.abstract?
          next unless registered_class.uri_template

          existing_template_data = parse_uri_template(registered_class.uri_template)

          # Check if schema and structure are the same
          if new_template_data[:schema] == existing_template_data[:schema] &&
            are_potentially_ambiguous?(new_template_data[:pattern], existing_template_data[:pattern])

            # Use a consistent error message format for all conflicts
            raise ArgumentError, "URI template conflict detected: '#{new_template}' conflicts with existing template '#{registered_class.uri_template}' registered by #{registered_class.name}"
          end
        end
      end

      # Determine if two normalized patterns could be ambiguous
      def are_potentially_ambiguous?(pattern1, pattern2)
        # If the patterns are exactly the same, they're definitely ambiguous
        return true if pattern1 == pattern2

        # Split into segments to compare structure
        segments1 = pattern1.split('/')
        segments2 = pattern2.split('/')

        # If different number of segments, they can't be ambiguous
        return false if segments1.size != segments2.size

        # Count parameter segments
        param_segments1 = segments1.count { |s| s.include?('{param}') }
        param_segments2 = segments2.count { |s| s.include?('{param}') }

        # If they have different number of parameter segments, they're not ambiguous
        return false if param_segments1 != param_segments2

        # If we have the same number of segments and same number of parameters,
        # but the patterns aren't identical, they could be ambiguous
        # due to parameter position swapping
        if param_segments1 > 0 && param_segments1 == param_segments2
          # Create pattern maps (P for param, S for static)
          pattern_map1 = segments1.map { |s| s.include?('{param}') ? 'P' : 'S' }
          pattern_map2 = segments2.map { |s| s.include?('{param}') ? 'P' : 'S' }

          # If pattern maps are different but have same param count, potentially ambiguous
          return pattern_map1 != pattern_map2
        end

        false
      end
    end

    attr_reader :description, :uri_template, :mime_type
  end
end

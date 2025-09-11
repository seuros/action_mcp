# frozen_string_literal: true

require "active_model"

module ActionMCP
  class ResourceTemplate
    # Add ActiveModel capabilities
    include ActiveModel::Model
    include ActiveModel::Validations
    include ResourceCallbacks
    include UriAmbiguityChecker
    include CurrentHelpers

    # Track all registered templates
    @registered_templates = []
    attr_reader :execution_context, :description, :uri_template, :mime_type

    class << self
      attr_reader :registered_templates, :description, :uri_template,
                  :mime_type, :template_name, :parameters, :_meta

      def abstract?
        @abstract ||= false
      end

      def abstract!
        @abstract = true
        # Unregister from the appropriate registry if already registered
        return unless ActionMCP::ResourceTemplatesRegistry.items.values.include?(self)

        ActionMCP::ResourceTemplatesRegistry.unregister(self)
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@abstract, false)
        # Create a copy of validation requirements for subclasses
        subclass.instance_variable_set(:@required_parameters, [])

        # Run the ActiveSupport load hook when a resource template is defined
        subclass.class_eval do
          ActiveSupport.run_load_hooks(:action_mcp_resource_template, subclass)
        end
      end

      # Track required parameters for validation
      def required_parameters
        @required_parameters ||= []
      end

      def parameter(name, description:, required: false, **options)
        @parameters ||= {}
        @parameters[name] = { description: description, required: required, **options }

        # Define attribute accessor if not already defined
        attr_accessor name unless method_defined?(name) && method_defined?("#{name}=")

        # Track required parameters for validation
        required_parameters << name if required
      end

      # Alias parameter to attribute for clarity
      alias attribute parameter

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

      # Sets or retrieves the _meta field
      def meta(data = nil)
        if data
          raise ArgumentError, "_meta must be a hash" unless data.is_a?(Hash)

          @_meta ||= {}
          @_meta = @_meta.merge(data)
        else
          @_meta || {}
        end
      end

      def to_h
        name_value = defined?(@template_name) ? @template_name : name.demodulize.underscore.gsub(/_template$/, "")

        result = {
          uriTemplate: @uri_template,
          name: name_value,
          description: @description,
          mimeType: @mime_type
        }.compact

        # Add _meta if present
        result[:_meta] = @_meta if @_meta&.any?

        result
      end

      def capability_name
        return "" if name.nil?

        @capability_name ||= name.demodulize.underscore.sub(/_template$/, "")
      end

      # Process a URI string to create a template instance
      def process(uri_string)
        return nil unless @uri_template

        # Extract parameters from URI using pattern matching
        params = extract_params_from_uri(uri_string)
        return new if params.nil? # Return invalid template for bad URI

        # Create new instance with the extracted parameters
        new(params)
      end

      private

      # Extract parameters from a URI using the template pattern
      def extract_params_from_uri(uri_string)
        # Convert template parameters to named capture groups
        regex_parts = []
        current_pos = 0
        param_names = []

        # Find all template parameters like {param_name}
        @uri_template.scan(/\{([^}]+)\}/) do |param_name|
          param_names << param_name[0]

          # Get the position of this parameter in the template
          param_start = @uri_template.index("{#{param_name[0]}}", current_pos)

          # Add the text before the parameter (escaped)
          if param_start > current_pos
            prefix = Regexp.escape(@uri_template[current_pos...param_start])
            regex_parts << prefix
          end

          # Add the named capture group
          regex_parts << "(?<#{param_name[0]}>[^/]+)"

          # Update current position
          current_pos = param_start + param_name[0].length + 2 # +2 for { and }
        end

        # Add any remaining text after the last parameter
        if current_pos < @uri_template.length
          suffix = Regexp.escape(@uri_template[current_pos..])
          regex_parts << suffix
        end

        # Build the final regex
        regex_pattern = regex_parts.join
        regex = Regexp.new("^#{regex_pattern}$")

        # Try to match the URI
        match_data = regex.match(uri_string)
        return nil unless match_data

        # Extract named captures as parameters
        params = {}
        param_names.each do |name|
          params[name.to_sym] = match_data[name] if match_data[name]
        end

        params
      end

      # Extract the schema and pattern from a URI template
      def parse_uri_template(template)
        # Parse the URI template to get schema and pattern
        # Format: schema://path/{param1}/{param2}...
        if template =~ %r{^([^:]+)://(.+)$}
          schema = ::Regexp.last_match(1)
          pattern = ::Regexp.last_match(2)

          # Replace parameter placeholders with generic markers to compare structure
          normalized_pattern = pattern.gsub(/\{[^}]+\}/, "{param}")

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
          # Ignore conflicts with resource templates that have the same name
          next if registered_class.name == name

          existing_template_data = parse_uri_template(registered_class.uri_template)

          # Check if schema and structure are the same
          next unless new_template_data[:schema] == existing_template_data[:schema] &&
                      are_potentially_ambiguous?(new_template_data[:pattern], existing_template_data[:pattern])

          # Use a consistent error message format for all conflicts
          raise ArgumentError,
                "URI template conflict detected: '#{new_template}' conflicts with existing template '#{registered_class.uri_template}' registered by #{registered_class.name}"
        end
      end
    end

    # Initialize with attribute values
    def initialize(attributes = {})
      super(attributes)
      @execution_context = {}
      validate!
    end

    # Override validate! to not raise exceptions
    def validate!
      valid?
    end

    def with_context(context)
      @execution_context = context
      self
    end

    def session
      execution_context[:session]
    end

    # Add custom validation for required parameters
    validate do |_template|
      self.class.required_parameters.each do |param|
        errors.add(param, "can't be blank") if send(param).nil? || send(param).to_s.empty?
      end
    end

    def call
      @response = ResourceResponse.new

      # Validate parameters first
      unless valid?
        missing_params = errors.full_messages
        @response.mark_as_parameter_validation_failed!(missing_params, "template://#{self.class.name}")
        return @response
      end

      begin
        run_callbacks :resolve do
          result = resolve
          if result.nil?
            @response.mark_as_not_found!("template://#{self.class.name}")
          else
            @response.add_content(result)
          end
          @response
        end
      rescue StandardError => e
        @response.mark_as_resolution_failed!("template://#{self.class.name}", e.message)
      end

      @response
    end
  end
end

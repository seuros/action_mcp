# frozen_string_literal: true

require "active_model"
require "addressable/template"
require "addressable/uri"

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
    attr_reader :execution_context, :resolved_uri

    # Delegate to class-level DSL values so instances see template metadata.
    delegate :description, :uri_template, :mime_type, to: :class

    class << self
      attr_reader :registered_templates, :description, :uri_template,
                  :mime_type, :template_name, :parameters, :_meta, :ui_meta

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

      def addressable_template_cache
        @addressable_template_cache ||= {}
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
        return @mime_type unless value

        @mime_type = ActionMCP::MimeTypes.resolve(value)
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

      # Declares MCP Apps UI metadata for this resource template. Stored verbatim
      # (camelCase keys per the ext-apps spec). Used both for the `resources/list`
      # entry's `_meta.ui` and the default content `_meta.ui` produced by
      # `render_ui`.
      #
      # @example
      #   ui csp: { connectDomains: %w[api.openweathermap.org] }, prefersBorder: true
      def ui(**data)
        raise ArgumentError, "ui metadata must not be empty" if data.empty?

        validate_ui_metadata!(data)
        @ui_meta ||= {}
        @ui_meta = @ui_meta.deep_merge(data)
      end

      def meta_with_ui(meta = nil)
        supplied_meta = coerce_meta(meta)
        ui_meta = @ui_meta&.any? ? { ui: @ui_meta } : {}
        combined = ui_meta.deep_merge(supplied_meta)

        return nil if combined.empty?

        ui_present, combined_ui = metadata_value(combined, :ui)
        validate_ui_metadata!(combined_ui) if ui_present
        combined
      end

      private

      def validate_ui_metadata!(data)
        raise ArgumentError, "ui metadata must be a hash" unless data.is_a?(Hash)

        validate_ui_keys!(data, Apps::UI_META_KEYS, "metadata")
        csp_present, csp = metadata_value(data, :csp)
        permissions_present, permissions = metadata_value(data, :permissions)
        domain_present, domain = metadata_value(data, :domain)
        border_present, border = metadata_value(data, :prefersBorder)

        validate_ui_csp_origins!(csp) if csp_present
        validate_ui_permissions!(permissions) if permissions_present
        if domain_present && !domain.is_a?(String)
          raise ArgumentError, "ui domain must be a string, got: #{domain.inspect}"
        end
        if border_present && border != true && border != false
          raise ArgumentError, "ui prefersBorder must be true or false, got: #{border.inspect}"
        end
      end

      def validate_ui_csp_origins!(csp)
        raise ArgumentError, "ui csp must be a hash" unless csp.is_a?(Hash)

        validate_ui_keys!(csp, Apps::CSP_KEYS, "csp")
        Apps::CSP_KEYS.each do |key|
          pattern = key == :connectDomains ? Apps::CONNECT_ORIGIN_PATTERN : Apps::RESOURCE_ORIGIN_PATTERN
          scheme_message = key == :connectDomains ? "http(s):// or ws(s)://" : "http(s)://"
          metadata_values(csp, key).each do |origins|
            unless origins.is_a?(Array)
              raise ArgumentError, "ui csp #{key} must be an array, got: #{origins.inspect}"
            end

            origins.each do |origin|
              next if origin.is_a?(String) && pattern.match?(origin)

              raise ArgumentError,
                    "ui csp #{key} entries must be #{scheme_message} origins, got: #{origin.inspect}"
            end
          end
        end
      end

      def validate_ui_permissions!(permissions)
        raise ArgumentError, "ui permissions must be a hash" unless permissions.is_a?(Hash)

        validate_ui_keys!(permissions, Apps::PERMISSION_KEYS, "permissions")

        permissions.each do |key, value|
          next if value.respond_to?(:to_hash)

          raise ArgumentError, "ui permissions #{key} value must be a hash, got: #{value.inspect}"
        end
      end

      def coerce_meta(meta)
        coerced =
          if meta.nil?
            {}
          elsif meta.respond_to?(:to_hash)
            meta.to_hash
          elsif meta.respond_to?(:to_h)
            meta.to_h
          else
            raise ArgumentError, "meta must respond to :to_hash or :to_h, got: #{meta.class}"
          end

        coerced = coerced.deep_dup
        coerced[:ui] = coerced.delete("ui") if coerced.key?("ui") && !coerced.key?(:ui)
        coerced
      end

      def metadata_value(data, key)
        return [ true, data[key] ] if data.key?(key)
        return [ true, data[key.to_s] ] if data.key?(key.to_s)

        [ false, nil ]
      end

      def metadata_values(data, key)
        values = []
        values << data[key] if data.key?(key)
        values << data[key.to_s] if data.key?(key.to_s)
        values
      end

      def validate_ui_keys!(data, allowed_keys, label)
        invalid = data.keys.reject do |key|
          key.respond_to?(:to_sym) && allowed_keys.include?(key.to_sym)
        end
        return if invalid.empty?

        raise ArgumentError,
              "ui #{label} keys must be #{allowed_keys.join('/')}, got: #{invalid.inspect}"
      end

      public

      def to_h
        name_value = defined?(@template_name) ? @template_name : name.demodulize.underscore.gsub(/_template$/, "")

        result = {
          uriTemplate: @uri_template,
          name: name_value,
          description: @description,
          mimeType: @mime_type
        }.compact

        meta = meta_with_ui(@_meta)
        result[:_meta] = meta if meta&.any?

        result
      end

      def capability_name
        return "" if name.nil?

        @capability_name ||= name.demodulize.underscore.sub(/_template$/, "")
      end

      # --- Static resource listing API ---

      # Override in subclasses to enumerate concrete resources.
      # Returns Array<ActionMCP::Resource>.
      #
      # @param session [Object, nil] The current MCP session
      # @return [Array<ActionMCP::Resource>]
      def list(session: nil)
        []
      end

      # Returns true if this template subclass overrides +list+.
      def lists_resources?
        method(:list).owner != ActionMCP::ResourceTemplate.singleton_class
      end

      # Factory helper that fills in template-level defaults.
      #
      # @param uri [String] The concrete resource URI
      # @param name [String] Display name
      # @param title [String, nil] Human-readable title
      # @param description [String, nil] Falls back to template description
      # @param mime_type [String, nil] Falls back to template mime_type
      # @param size [Integer, nil] Size in bytes
      # @param annotations [Hash, nil] Optional annotations
      # @param meta [Hash, #to_hash, #to_h, nil] Optional extension metadata passed through to the Resource (emitted as `_meta`)
      # @return [ActionMCP::Resource]
      def build_resource(uri:, name:, title: nil, description: nil, mime_type: nil, size: nil, annotations: nil, meta: nil)
        ActionMCP::Resource.new(
          uri: uri,
          name: name,
          title: title,
          description: description || @description,
          mime_type: mime_type || @mime_type,
          size: size,
          annotations: annotations,
          meta: meta_with_ui(meta)
        )
      end

      # Check if a concrete URI is readable by this template.
      # Returns false if the URI doesn't match the template pattern.
      #
      # @param uri [String] A concrete URI to check
      # @return [Boolean]
      def readable_uri?(uri)
        return false unless @uri_template

        params = extract_params_from_uri(uri)
        return false if params.nil?

        new(params).valid?
      rescue StandardError
        false
      end

      # Process a URI string to create a template instance
      def process(uri_string)
        return nil unless @uri_template

        # Extract parameters from URI using pattern matching
        params = extract_params_from_uri(uri_string)
        return new if params.nil? # Return invalid template for bad URI

        # Preserve the concrete URI requested by the client. The template URI
        # may contain placeholders and must not leak into resource contents.
        new(params).tap { |record| record.instance_variable_set(:@resolved_uri, uri_string) }
      end

      private

      # Extract parameters from a URI using the template pattern
      def extract_params_from_uri(uri_string)
        extracted = compiled_uri_template(@uri_template).extract(uri_string)
        extracted&.transform_keys(&:to_sym)
      end

      # Extract the schema and pattern from a URI template
      def parse_uri_template(template)
        addressable_template = compiled_uri_template(template)
        variables = addressable_template.variables.index_with.with_index do |_, index|
          "action_mcp_parameter_#{index}"
        end
        expanded = addressable_template.expand(variables).to_s
        parsed_uri = Addressable::URI.parse(expanded)
        raise ArgumentError, "Invalid URI template format: #{template}" if parsed_uri.scheme.blank?

        normalized_pattern = expanded.delete_prefix("#{parsed_uri.scheme}:").delete_prefix("//")
        variables.each_value { |marker| normalized_pattern.gsub!(marker, "{param}") }

        { schema: parsed_uri.scheme, pattern: normalized_pattern, original: template }
      rescue Addressable::URI::InvalidURIError,
             Addressable::Template::InvalidTemplateValueError,
             Addressable::Template::InvalidTemplateOperatorError => e
        raise ArgumentError, "Invalid URI template format: #{template} (#{e.message})"
      end

      def compiled_uri_template(template)
        addressable_template_cache[template] ||= Addressable::Template.new(template)
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

    # Build a `Content::Resource` for an MCP Apps UI view. Accepts either a raw
    # `:text` string or a Rails `:template` path; the class-level `ui` macro
    # supplies the content-level `_meta.ui` automatically.
    #
    # @example
    #   render_ui(template: "mcp/ui/weather_dashboard")
    def render_ui(text: nil, template: nil, layout: false, locals: {}, meta: nil)
      raise ArgumentError, "render_ui accepts either :text or :template, not both" if !text.nil? && !template.nil?

      resolved =
        if !text.nil?
          text
        elsif !template.nil?
          rendered = ActionMCP::MCPAppRenderer.render(template: template, layout: layout, locals: locals)
          if rendered.to_s.strip.empty?
            ActionMCP.logger.warn(
              "[ActionMCP] render_ui produced empty output for #{self.class.name} " \
              "(uri_template=#{self.class.uri_template.inspect}, template=#{template.inspect}). " \
              "Check the template path and host view configuration."
            )
          end
          rendered
        else
          raise ArgumentError, "render_ui requires :text or :template"
        end

      resource_uri = resolved_uri || self.class.uri_template
      unless resource_uri.is_a?(String) && ActionMCP::Apps::URI_SCHEME.match?(resource_uri)
        raise ArgumentError, "render_ui requires a concrete ui:// resource URI, got: #{resource_uri.inspect}"
      end
      if resolved_uri.nil? && resource_uri.match?(/\{[^}]+\}/)
        raise ArgumentError, "render_ui cannot emit a parameterized URI template without a concrete request URI"
      end

      resource_mime_type = self.class.mime_type || ActionMCP::Apps::MIME_TYPE
      unless resource_mime_type == ActionMCP::Apps::MIME_TYPE
        raise ArgumentError,
              "render_ui requires mime type #{ActionMCP::Apps::MIME_TYPE.inspect}, got: #{resource_mime_type.inspect}"
      end
      unless resolved.is_a?(String)
        raise ArgumentError, "render_ui content must be a string, got: #{resolved.class}"
      end

      ActionMCP::Content::Resource.new(
        resource_uri,
        resource_mime_type,
        text: resolved,
        meta: self.class.meta_with_ui(meta)
      )
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

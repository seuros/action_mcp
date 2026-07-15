# frozen_string_literal: true

module ActionMCP
  module Apps
    # Namespace for ResourceTemplate classes generated from a compiled-views
    # manifest.
    module Views; end

    # Loads `.action_mcp/views/manifest.json` (emitted by
    # @action-mcp/vite-plugin) and registers one ResourceTemplate per compiled
    # view, serving the bundle inlined into an HTML shell as a `ui://` resource.
    class ViewManifest
      SCHEMA_VERSION = 1
      MANIFEST_FILENAME = "manifest.json"

      class Error < StandardError; end

      class << self
        # Registers templates for every view in the manifest. Idempotent:
        # previously generated view classes are evicted first, so rebuilt
        # manifests (new hashes) load cleanly on app reload.
        #
        # @return [Array<Class>] the generated ResourceTemplate subclasses
        def load!(dir = nil)
          dir = resolve_dir(dir)
          manifest_path = File.join(dir, MANIFEST_FILENAME)
          unless File.exist?(manifest_path)
            evict_generated_templates!
            return []
          end

          data = parse_manifest(manifest_path)
          evict_generated_templates!

          aliases = {}
          classes = data.fetch("views", {}).map do |name, entry|
            klass, logical_uri, resource_uri = register_view(dir, name, entry)
            if aliases.key?(logical_uri)
              raise Error, "Duplicate logicalUri #{logical_uri.inspect} in views manifest"
            end

            aliases[logical_uri] = resource_uri
            klass
          end
          @resource_uri_aliases = aliases.freeze
          classes
        rescue StandardError
          evict_generated_templates!
          raise
        end

        # Resolves the stable URI declared by a tool to the content-addressed
        # resource URI currently registered from the compiled views manifest.
        def resolve_resource_uri(uri)
          (@resource_uri_aliases || {}).fetch(uri, uri)
        end

        private

        def resolve_dir(dir)
          path = (dir || ActionMCP.configuration.mcp_apps_views_path).to_s
          return path if File.absolute_path?(path)

          defined?(Rails) && Rails.root ? Rails.root.join(path).to_s : File.expand_path(path)
        end

        def parse_manifest(path)
          data = JSON.parse(File.read(path))
          version = data["schemaVersion"]
          unless version == SCHEMA_VERSION
            raise Error, "Unsupported views manifest schemaVersion #{version.inspect} at #{path} " \
                         "(expected #{SCHEMA_VERSION}; rebuild with a matching @action-mcp/vite-plugin)"
          end
          data
        rescue JSON::ParserError => e
          raise Error, "Invalid views manifest at #{path}: #{e.message}"
        end

        def evict_generated_templates!
          generated = Views.constants(false).filter_map do |const|
            Views.const_get(const, false)
          end

          generated.concat(ResourceTemplate.registered_templates.select { |klass| generated_template?(klass) })
          generated.concat(ResourceTemplatesRegistry.items.values.select { |klass| generated_template?(klass) })
          generated.uniq!

          ResourceTemplate.registered_templates.delete_if do |klass|
            generated.include?(klass) || generated_template?(klass)
          end
          ResourceTemplatesRegistry.items.delete_if do |_name, klass|
            generated.include?(klass) || generated_template?(klass)
          end

          Views.constants(false).each do |const|
            Views.send(:remove_const, const)
          end

          @resource_uri_aliases = {}.freeze
        end

        def generated_template?(klass)
          klass.is_a?(Class) && klass.name&.start_with?("#{Views.name}::")
        end

        def register_view(dir, name, entry)
          unless entry.is_a?(Hash)
            raise Error, "Views manifest entry for #{name.inspect} must be an object"
          end

          bundle_path = File.join(dir, entry.fetch("file"))
          unless File.exist?(bundle_path)
            raise Error, "Views manifest references missing bundle #{entry['file'].inspect} for view #{name.inspect}. " \
                         "Rebuild with action-mcp-build-views."
          end

          uri = entry.fetch("uri")
          logical_uri = entry.fetch("logicalUri", "ui://views/#{name}")
          validate_view_uri!(uri, field: "uri", view_name: name)
          validate_view_uri!(logical_uri, field: "logicalUri", view_name: name)
          ui_meta = entry["ui"]

          klass = Class.new(ResourceTemplate)
          const_name = "#{name.underscore.camelize}View"
          Views.const_set(const_name, klass)
          # The inheritance hook sees the class before it has a constant name
          # and may cache/register the empty capability name. Reset that state
          # now that the generated class has its final identity.
          klass.remove_instance_variable(:@capability_name) if klass.instance_variable_defined?(:@capability_name)

          klass.class_eval do
            description "Compiled MCP Apps view: #{name}"
            uri_template uri
            mime_type :mcp_app
            ui(**ui_meta.deep_symbolize_keys) if ui_meta.is_a?(Hash) && ui_meta.any?

            define_method(:resolve) do
              render_ui(text: ViewManifest.send(:html_shell, name, bundle_path))
            end
          end

          ResourceTemplatesRegistry.items.delete_if { |_key, registered| registered.equal?(klass) }
          ResourceTemplatesRegistry.register(klass)

          [ klass, logical_uri, uri ]
        end

        def validate_view_uri!(uri, field:, view_name:)
          return if uri.is_a?(String) && Apps::URI_SCHEME.match?(uri)

          raise Error, "Views manifest #{field} for #{view_name.inspect} must be a ui:// URI, got: #{uri.inspect}"
        end

        def html_shell(name, bundle_path)
          js = File.read(bundle_path).gsub("</script", "<\\/script")
          <<~HTML
            <!doctype html>
            <html>
              <head><meta charset="utf-8"><title>#{ERB::Util.html_escape(name)}</title></head>
              <body>
                <div id="root"></div>
                <script type="module">#{js}</script>
              </body>
            </html>
          HTML
        end
      end
    end
  end
end

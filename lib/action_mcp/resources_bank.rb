# frozen_string_literal: true

# frozen_string_literal: true

module ActionMCP
  module ResourcesBank
    @resources = {}    # { uri => content_object }
    @templates  = {}   # { uri => template_object }
    @watchers   = {}   # { source_uri => watcher }

    class << self
      # Basic resource registration.
      def register_resource(uri, content)
        @resources[uri] = content
      end

      def all_resources
        @resources.values
      end

      def read(uri)
        @resources[uri]
      end

      def register_template(uri, template)
        @templates[uri] = template
      end

      def all_templates
        @templates.values
      end

      # Registers a source (file or directory) for resources.
      #
      # @param source_uri [String] An identifier for this source.
      # @param path [String] Filesystem path to the source.
      # @param watch [Boolean] Whether to watch the source for changes.
      def register_source(source_uri, path, watch: false)
        reload_source(source_uri, path) # Initial load

        if watch
          require "active_support/evented_file_update_checker"
          # Watch all files under the given path (recursive)
          file_paths = Dir.glob("#{path}/**/*")
          watcher = ActiveSupport::EventedFileUpdateChecker.new(file_paths) do |modified, added, removed|
            Rails.logger.info("Files changed in #{path} - Modified: #{modified.inspect}, Added: #{added.inspect}, Removed: #{removed.inspect}")
            # Reload resources for this source when changes occur.
            reload_source(source_uri, path)
          end
          @watchers[source_uri] = { path: path, watcher: watcher }
        end
      end

      # Unregisters a source and stops watching it.
      #
      # @param source_uri [String] The identifier for the source.
      def unregister_source(source_uri)
        @watchers.delete(source_uri)
        # Optionally, remove any resources associated with this source.
        @resources.reject! { |uri, _| uri.start_with?("#{source_uri}://") }
      end

      # Reloads (or loads) all resources from the given directory.
      #
      # @param source_uri [String] The identifier for the source.
      # @param path [String] Filesystem path to the source.
      def reload_source(source_uri, path)
        Rails.logger.info("Reloading resources from #{path} for #{source_uri}")
        Dir.glob("#{path}/**/*").each do |file|
          next unless File.file?(file)
          # Create a resource URI from the source and file path.
          relative_path = file.sub(%r{\A#{Regexp.escape(path)}/?}, "")
          resource_uri = "#{source_uri}://#{relative_path}"
          # For this example, we assume text files.
          begin
            text = File.read(file)
            content = ActionMCP::Content::Text.new(text)
            register_resource(resource_uri, content)
            Rails.logger.info("Registered resource: #{resource_uri}")
          rescue StandardError => e
            Rails.logger.error("Error reading file #{file}: #{e.message}")
          end
        end
      end

      # This method should be called periodically (e.g. via a background thread)
      # to check if any watched files have changed.
      def run_watchers
        @watchers.each_value do |data|
          data[:watcher].execute_if_updated
        end
      end
    end
  end
end

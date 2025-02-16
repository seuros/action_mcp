# frozen_string_literal: true

require "base64"

module ActionMCP
  # Manages resources and templates.
  module ResourcesBank
    @resources = {}    # { uri => content_object }
    @templates  = {}   # { uri => template_object }
    @watchers   = {}   # { source_uri => watcher }

    class << self
      # Registers a resource.
      #
      # @param uri [String] The URI of the resource.
      # @param content [Content::Resource] The content of the resource.
      # @return [void]
      def register_resource(uri, content)
        @resources[uri] = content
      end

      # Returns all registered resources.
      #
      # @return [Array<Content::Resource>] An array of all registered resources.
      def all_resources
        @resources.values
      end

      # Reads a resource by URI.
      #
      # @param uri [String] The URI of the resource to read.
      # @return [Content::Resource, nil] The resource, or nil if not found.
      def read(uri)
        @resources[uri]
      end

      # Registers a template.
      #
      # @param uri [String] The URI of the template.
      # @param template [Object] The template object.
      # @return [void]
      def register_template(uri, template)
        @templates[uri] = template
      end

      # Returns all registered templates.
      #
      # @return [Array<Object>] An array of all registered templates.
      def all_templates
        @templates.values
      end

      # Registers a source (file or directory) for resources.
      #
      # @param source_uri [String] An identifier for this source.
      # @param path [String] Filesystem path to the source.
      # @param watch [Boolean] Whether to watch the source for changes.
      # @return [void]
      def register_source(source_uri, path, watch: false)
        reload_source(source_uri, path) # Initial load

        return unless watch

        require "active_support/evented_file_update_checker"
        # Watch all files under the given path (recursive)
        file_paths = Dir.glob("#{path}/**/*")
        watcher = ActiveSupport::EventedFileUpdateChecker.new(file_paths) do |modified, added, removed|
          Transport.logger.debug("Files changed in #{path} - Modified: #{modified.inspect}, Added: #{added.inspect}, Removed: #{removed.inspect}")
          # Reload resources for this source when changes occur.
          reload_source(source_uri, path)
        end
        @watchers[source_uri] = { path: path, watcher: watcher }
      end

      # Unregisters a source and stops watching it.
      #
      # @param source_uri [String] The identifier for the source.
      # @return [void]
      def unregister_source(source_uri)
        @watchers.delete(source_uri)
        # Optionally, remove any resources associated with this source.
        @resources.reject! { |uri, _| uri.start_with?("#{source_uri}://") }
      end

      # Reloads (or loads) all resources from the given directory.
      #
      # @param source_uri [String] The identifier for the source.
      # @param path [String] Filesystem path to the source.
      # @return [void]
      def reload_source(source_uri, path)
        Transport.logger.debug("Reloading resources from #{path} for #{source_uri}")
        Dir.glob("#{path}/**/*").each do |file|
          next unless File.file?(file)

          # Create a resource URI from the source and file path.
          relative_path = file.sub(%r{\A#{Regexp.escape(path)}/?}, "")
          resource_uri = "#{source_uri}://#{relative_path}"
          begin
            text = File.read(file)
            mime_type = `file --mime-type -b #{file}`.strip
            if mime_type.start_with?("text/")
              content = ActionMCP::Content::Resource.new(resource_uri, mime_type, text: text, blob: nil)
            else
              content = ActionMCP::Content::Resource.new(resource_uri, mime_type, text: nil, blob: Base64.encode64(text))
            end
            register_resource(resource_uri, content)
            Transport.logger.debug("Registered resource: #{resource_uri}")
          rescue StandardError => e
            Transport.logger.error("Error reading file '#{file}': #{e.message}")
          end
        end
      end

      # This method should be called periodically (e.g. via a background thread)
      # to check if any watched files have changed.
      #
      # @return [void]
      def run_watchers
        @watchers.each_value do |data|
          data[:watcher].execute_if_updated
        end
      end

      # Handles the resources/list request.
      #
      # @param params [Hash] The parameters for the request.
      # @return [Hash] A hash containing the list of resources.
      def handle_list_resources(params)
        resources_data = @resources.map { |uri, content| @resources[uri].to_h }
        { resources: resources_data }
      end

      # Handles the resources/read request.
      #
      # @param params [Hash] The parameters for the request.
      # @return [Hash] A hash containing the resource content.
      def handle_read_resource(params)
        uri = params["uri"]
        resource = @resources[uri]
        unless resource
          return { error: { code: -32002, message: "Resource not found", data: { uri: uri } } }
        end

        content_data = { uri: uri, mimeType: resource.mime_type, text: resource.text }

        { contents: [ content_data ] }
      end

      # Handles the resources/templates/list request.
      #
      # @param params [Hash] The parameters for the request.
      # @return [Hash] A hash containing the list of templates.
      def handle_list_templates(params)
        templates_data = all_templates.map do |template|
          {
            uriTemplate: template.uri, # Assuming template.uri contains the URI template
            name: template.name,
            description: template.description,
            mimeType: template.mime_type
          }.compact
        end
        { resourceTemplates: templates_data }
      end

      # Handles the resources/subscribe request.
      #
      # @param params [Hash] The parameters for the request.
      # @return [Hash] An empty hash to indicate success.
      def handle_subscribe_resource(params)
        uri = params["uri"]
        # In a real implementation, you would likely store the subscription
        # and send notifications when the resource changes.
        Transport.logger.info("Subscribed to resource: #{uri}")
        # TODO: Send notifications/resources/updated notification when the resource changes
        {} # Return an empty hash to indicate success
      end

      # Sends the notifications/resources/list_changed notification.
      #
      # @return [void]
      def send_list_changed_notification
        # TODO: Implement the logic to send the notifications/resources/list_changed notification
        Transport.logger.info("Sending notifications/resources/list_changed notification")
      end
    end
  end
end

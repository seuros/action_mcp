# frozen_string_literal: true

module ActionMCP
  module Content
    # ResourceLink represents a link to a resource that the server is capable of reading.
    # It's included in a prompt or tool call result.
    # Note: resource links returned by tools are not guaranteed to appear in resources/list requests.
    class ResourceLink < Base
      # @return [String] The URI of the resource.
      # @return [String] The name of the resource.
      # @return [String, nil] The description of the resource (optional).
      # @return [String, nil] The MIME type of the resource (optional).
      attr_reader :uri, :name, :description, :mime_type

      # Initializes a new ResourceLink content.
      #
      # @param uri [String] The URI of the resource.
      # @param name [String] The name of the resource.
      # @param description [String, nil] The description of the resource (optional).
      # @param mime_type [String, nil] The MIME type of the resource (optional).
      # @param annotations [Hash, nil] Optional annotations for the resource link.
      def initialize(uri, name:, description: nil, mime_type: nil, annotations: nil)
        raise ArgumentError, "uri must be a non-empty string" unless uri.is_a?(String) && uri.present?
        raise ArgumentError, "name must be a non-empty string" unless name.is_a?(String) && name.present?
        unless description.nil? || description.is_a?(String)
          raise ArgumentError, "description must be a string or nil"
        end
        unless mime_type.nil? || mime_type.is_a?(String)
          raise ArgumentError, "mime_type must be a string or nil"
        end

        super("resource_link", annotations: annotations)
        @uri = uri
        @name = name
        @description = description
        @mime_type = mime_type
        to_h
      end

      # Returns a hash representation of the resource link content.
      #
      # @return [Hash] The hash representation of the resource link content.
      def to_h
        result = super.merge(uri: @uri, name: @name)
        result[:description] = @description if @description
        result[:mimeType] = @mime_type if @mime_type
        Validation.validate_content_block!(result)
        result
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module Content
    # ResourceLink represents a link to a resource that the server is capable of reading.
    # It's included in a prompt or tool call result.
    # Note: resource links returned by tools are not guaranteed to appear in resources/list requests.
    class ResourceLink < Base
      # @return [String] The URI of the resource.
      # @return [String, nil] The name of the resource (optional).
      # @return [String, nil] The description of the resource (optional).
      # @return [String, nil] The MIME type of the resource (optional).
      attr_reader :uri, :name, :description, :mime_type

      # Initializes a new ResourceLink content.
      #
      # @param uri [String] The URI of the resource.
      # @param name [String, nil] The name of the resource (optional).
      # @param description [String, nil] The description of the resource (optional).
      # @param mime_type [String, nil] The MIME type of the resource (optional).
      # @param annotations [Hash, nil] Optional annotations for the resource link.
      def initialize(uri, name: nil, description: nil, mime_type: nil, annotations: nil)
        super("resource_link", annotations: annotations)
        @uri = uri
        @name = name
        @description = description
        @mime_type = mime_type
      end

      # Returns a hash representation of the resource link content.
      #
      # @return [Hash] The hash representation of the resource link content.
      def to_h
        result = super.merge(uri: @uri)
        result[:name] = @name if @name
        result[:description] = @description if @description
        result[:mimeType] = @mime_type if @mime_type
        result
      end
    end
  end
end

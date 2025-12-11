# frozen_string_literal: true

module ActionMCP
  module Content
    # Resource content references a server-managed resource.
    # It includes a URI, MIME type, and optionally text content or a base64-encoded blob.
    class Resource < Base
      # @return [String] The URI of the resource.
      # @return [String] The MIME type of the resource.
      # @return [String, nil] The text content of the resource (optional).
      # @return [String, nil] The base64-encoded blob of the resource (optional).
      attr_reader :uri, :mime_type, :text, :blob, :annotations

      # Initializes a new Resource content.
      #
      # @param uri [String] The URI of the resource.
      # @param mime_type [String] The MIME type of the resource.
      # @param text [String, nil] The text content of the resource (optional).
      # @param blob [String, nil] The base64-encoded blob of the resource (optional).
      # @param annotations [Hash, nil] Optional annotations for the resource.
      def initialize(uri, mime_type = "text/plain", text: nil, blob: nil, annotations: nil)
        super("resource", annotations: annotations)
        @uri = uri
        @mime_type = mime_type
        @text = text
        @blob = blob
        @annotations = annotations
      end

      # Returns a hash representation of the resource content.
      # Per MCP spec, embedded resources have type "resource" with a nested resource object.
      #
      # @return [Hash] The hash representation of the resource content.
      def to_h
        inner = { uri: @uri, mimeType: @mime_type }
        inner[:text] = @text if @text
        inner[:blob] = @blob if @blob
        inner[:annotations] = @annotations if @annotations

        { type: @type, resource: inner }
      end
    end
  end
end

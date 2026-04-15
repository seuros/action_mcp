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
      # @return [Hash, nil] Optional _meta extension metadata on the resource contents.
      attr_reader :uri, :mime_type, :text, :blob, :annotations, :_meta

      # Initializes a new Resource content.
      #
      # @param uri [String] The URI of the resource.
      # @param mime_type [String] The MIME type of the resource.
      # @param text [String, nil] The text content of the resource (optional).
      # @param blob [String, nil] The base64-encoded blob of the resource (optional).
      # @param annotations [Hash, nil] Optional annotations for the resource.
      # @param _meta [Hash, nil] Optional _meta extension metadata.
      def initialize(uri, mime_type = "text/plain", text: nil, blob: nil, annotations: nil, _meta: nil)
        if _meta && !_meta.is_a?(Hash)
          raise ArgumentError, "_meta must be a Hash or nil, got: #{_meta.class}"
        end

        super("resource", annotations: annotations)
        @uri = uri
        @mime_type = mime_type
        @text = text
        @blob = blob
        @annotations = annotations
        @_meta = _meta
      end

      # Returns a hash representation of the resource content.
      # Per MCP spec, embedded resources have type "resource" with a nested resource object.
      # _meta, when present, belongs on the inner resource hash (TextResourceContents /
      # BlobResourceContents), not on the outer content envelope.
      #
      # @return [Hash] The hash representation of the resource content.
      def to_h
        inner = { uri: @uri, mimeType: @mime_type }
        inner[:text] = @text if @text
        inner[:blob] = @blob if @blob
        inner[:annotations] = @annotations if @annotations
        inner[:_meta] = @_meta if @_meta && !@_meta.empty?

        { type: @type, resource: inner }
      end
    end
  end
end

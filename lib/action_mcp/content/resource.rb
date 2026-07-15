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
      # @return [Hash, nil] Optional extension metadata (serialized on the wire as `_meta`).
      attr_reader :uri, :mime_type, :text, :blob, :annotations, :meta

      # Initializes a new Resource content.
      #
      # @param uri [String] The URI of the resource.
      # @param mime_type [String] The MIME type of the resource.
      # @param text [String, nil] The text content of the resource (optional).
      # @param blob [String, nil] The base64-encoded blob of the resource (optional).
      # @param annotations [Hash, nil] Optional annotations for the resource.
      # @param meta [Hash, #to_hash, #to_h, nil] Optional extension metadata. Emitted on the wire as `_meta`.
      def initialize(uri, mime_type = "text/plain", text: nil, blob: nil, annotations: nil, meta: nil)
        raise ArgumentError, "uri must be a non-empty string" unless uri.is_a?(String) && uri.present?
        unless mime_type.nil? || (mime_type.is_a?(String) && mime_type.present?)
          raise ArgumentError, "mime_type must be a non-empty string or nil"
        end
        unless [ !text.nil?, !blob.nil? ].one?
          raise ArgumentError, "embedded resources require exactly one of text or blob"
        end
        raise ArgumentError, "text must be a string" if !text.nil? && !text.is_a?(String)
        raise ArgumentError, "blob must be a base64 string" if !blob.nil? && !blob.is_a?(String)

        super("resource", annotations: annotations)
        @uri = uri
        @mime_type = mime_type
        @text = text
        @blob = blob
        @meta = meta.nil? ? nil : Validation.copy_object!(meta, "meta")
        to_h
      end

      # Returns a hash representation of the resource content.
      # Per MCP spec, embedded resources have type "resource" with a nested resource object.
      # `meta` is emitted as `_meta` on the inner resource hash (TextResourceContents /
      # BlobResourceContents), not on the outer content envelope.
      #
      # @return [Hash] The hash representation of the resource content.
      def to_h
        inner = { uri: @uri }
        inner[:mimeType] = @mime_type if @mime_type
        inner[:text] = @text if @text
        inner[:blob] = @blob if @blob
        inner[:_meta] = @meta if @meta && !@meta.empty?

        super.merge(resource: inner).tap { |result| Validation.validate_content_block!(result) }
      end
    end
  end
end

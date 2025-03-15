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
      attr_reader :uri, :mime_type, :text, :blob

      # Initializes a new Resource content.
      #
      # @param uri [String] The URI of the resource.
      # @param mime_type [String] The MIME type of the resource.
      # @param text [String, nil] The text content of the resource (optional).
      # @param blob [String, nil] The base64-encoded blob of the resource (optional).
      def initialize(uri, mime_type, text: nil, blob: nil)
        super("resource")
        @uri = uri
        @mime_type = mime_type
        @text = text
        @blob = blob
      end

      # Returns a hash representation of the resource content.
      #
      # @return [Hash] The hash representation of the resource content.
      def to_h
        resource_data = { uri: @uri, mimeType: @mime_type }
        resource_data[:text] = @text if @text
        resource_data[:blob] = @blob if @blob

        resource_data
      end
    end
  end
end

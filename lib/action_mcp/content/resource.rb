# frozen_string_literal: true

module ActionMCP
  module Content
    # Resource content references a server-managed resource.
    # It includes a URI, MIME type, and optionally text content or a base64-encoded blob.
    class Resource < Base
      attr_reader :uri, :mime_type, :text, :blob

      def initialize(uri, mime_type, text: nil, blob: nil)
        super("resource")
        @uri = uri
        @mime_type = mime_type
        @text = text
        @blob = blob
      end

      def to_h
        resource_data = { uri: @uri, mimeType: @mime_type }
        resource_data[:text] = @text if @text
        resource_data[:blob] = @blob if @blob

        super.merge(resource: resource_data)
      end
    end
  end
end

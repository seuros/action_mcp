# frozen_string_literal: true

module ActionMCP
  module Content
    # Image content includes base64-encoded image data and its MIME type.
    class Image < Binary
      # @param data [String] The base64-encoded image data.
      # @param mime_type [String] The MIME type of the image data.
      # @param annotations [Hash, nil] Optional annotations for the image content.
      def initialize(data, mime_type, annotations: nil)
        super("image", data, mime_type, annotations: annotations)
      end
    end
  end
end

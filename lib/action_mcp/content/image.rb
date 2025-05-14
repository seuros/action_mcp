# frozen_string_literal: true

module ActionMCP
  module Content
    # Image content includes a base64-encoded image and its MIME type.
    class Image < Base
      # @return [String] The base64-encoded image data.
      # @return [String] The MIME type of the image data.
      attr_reader :data, :mime_type

      # Initializes a new Image content.
      #
      # @param data [String] The base64-encoded image data.
      # @param mime_type [String] The MIME type of the image data.
      # @param annotations [Hash, nil] Optional annotations for the image content.
      def initialize(data, mime_type, annotations: nil)
        super("image", annotations: annotations)
        @data = data
        @mime_type = mime_type
      end

      # Returns a hash representation of the image content.
      #
      # @return [Hash] The hash representation of the image content.
      def to_h
        h = super.merge(data: @data, mimeType: @mime_type)
        h
      end
    end
  end
end

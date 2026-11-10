# frozen_string_literal: true

module ActionMCP
  module Content
    # Base64-encoded media content (image, audio) with its MIME type.
    class Binary < Base
      # @return [String] The base64-encoded data.
      # @return [String] The MIME type of the data.
      attr_reader :data, :mime_type

      # @param type [String] The content type ("image", "audio").
      # @param data [String] The base64-encoded data.
      # @param mime_type [String] The MIME type of the data.
      # @param annotations [Hash, nil] Optional annotations for the content.
      def initialize(type, data, mime_type, annotations: nil)
        super(type, annotations: annotations)
        @data = data
        @mime_type = mime_type
        to_h
      end

      # @return [Hash] The validated content block.
      def to_h
        super.merge(data: @data, mimeType: @mime_type).tap do |result|
          Validation.validate_content_block!(result)
        end
      end
    end
  end
end

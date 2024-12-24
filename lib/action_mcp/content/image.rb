# frozen_string_literal: true

module ActionMCP
  module Content
    # Image content includes a base64-encoded image and its MIME type.
    class Image < Base
      attr_reader :data, :mime_type

      def initialize(data, mime_type)
        super("image")
        @data = data
        @mime_type = mime_type
      end

      def to_h
        super.merge(data: @data, mimeType: @mime_type)
      end
    end
  end
end

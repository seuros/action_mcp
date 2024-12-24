# frozen_string_literal: true

module ActionMCP
  module Content
    # Audio content includes a base64-encoded audio clip and its MIME type.
    class Audio < Base
      attr_reader :data, :mime_type

      def initialize(data, mime_type)
        super("audio")
        @data = data
        @mime_type = mime_type
      end

      def to_h
        super.merge(data: @data, mimeType: @mime_type)
      end
    end
  end
end

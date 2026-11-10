# frozen_string_literal: true

module ActionMCP
  module Content
    # Audio content includes base64-encoded audio data and its MIME type.
    class Audio < Binary
      # @param data [String] The base64-encoded audio data.
      # @param mime_type [String] The MIME type of the audio data.
      # @param annotations [Hash, nil] Optional annotations for the audio content.
      def initialize(data, mime_type, annotations: nil)
        super("audio", data, mime_type, annotations: annotations)
      end
    end
  end
end

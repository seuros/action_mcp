# frozen_string_literal: true

module ActionMCP
  module Content
    # Audio content includes a base64-encoded audio clip and its MIME type.
    class Audio < Base
      # @return [String] The base64-encoded audio data.
      # @return [String] The MIME type of the audio data.
      attr_reader :data, :mime_type

      # Initializes a new Audio content.
      #
      # @param data [String] The base64-encoded audio data.
      # @param mime_type [String] The MIME type of the audio data.
      # @param annotations [Hash, nil] Optional annotations for the audio content.
      def initialize(data, mime_type, annotations: nil)
        super("audio", annotations: annotations)
        @data = data
        @mime_type = mime_type
      end

      # Returns a hash representation of the audio content.
      #
      # @return [Hash] The hash representation of the audio content.
      def to_h
        super.merge(data: @data, mimeType: @mime_type)
      end
    end
  end
end

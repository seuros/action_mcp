# frozen_string_literal: true

module ActionMCP
  # Module for rendering content.
  module Renderable
    # Renders content for Model Context Protocol responses.
    #
    # @param text [String, nil] Text content to render
    # @param audio [String, nil] Audio content to render
    # @param image [String, nil] Image content to render
    # @param resource [String, nil] Resource content to render
    # @param error [Array, nil] Array of error messages to render
    # @param mime_type [String, nil] MIME type for audio, image, or resource content
    # @param uri [String, nil] URI for resource content
    # @param blob [String, nil] Binary data for resource content
    #
    # @return [Content::Text, Content::Audio, Content::Image, Content::Resource, Hash]
    #   The rendered content object or error hash
    #
    # @raise [ArgumentError] If no valid content parameters are provided
    #
    # @example Render text content
    #   render(text: "Hello, world!")
    #
    # @example Render an error
    #   render(error: ["Invalid input", "Please try again"])
    def render(text: nil, audio: nil, image: nil, resource: nil, error: nil, mime_type: nil, uri: nil, blob: nil)
      if text
        Content::Text.new(text)
      elsif audio && mime_type
        Content::Audio.new(audio, mime_type)
      elsif image && mime_type
        Content::Image.new(image, mime_type)
      elsif resource && uri && mime_type
        Content::Resource.new(uri, mime_type, text: text, blob: blob)
      elsif error
        {
          isError: true,
          content: error.map { |e| render(text: e) }
        }
      else
        raise ArgumentError, "No content to render"
      end
    end
  end
end

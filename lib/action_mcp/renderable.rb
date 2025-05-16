# frozen_string_literal: true

module ActionMCP
  # Module for rendering content.
  module Renderable
    # Renders content for Model Context Protocol responses.
    #
    # @param text [String, nil] Text content to render
    # @param audio [String, nil] Audio content to render
    # @param image [String, nil] Image content to render
    # @param resource [String, nil] URI for resource content
    # @param mime_type [String, nil] MIME type for audio, image, or resource content
    # @param blob [String, nil] Binary data for resource content
    #
    # @return [Content::Text, Content::Audio, Content::Image, Content::Resource]
    #   The rendered content object
    #
    # @raise [ArgumentError] If no valid content parameters are provided
    #
    # @example Render text content
    #   render(text: "Hello, world!")
    #
    def render(text: nil, audio: nil, image: nil, resource: nil, mime_type: nil, blob: nil)
      if resource && mime_type
        Content::Resource.new(resource, mime_type, text: text, blob: blob, annotations: nil)
      elsif text
        Content::Text.new(text, annotations: nil)
      elsif audio && mime_type
        Content::Audio.new(audio, mime_type, annotations: nil)
      elsif image && mime_type
        Content::Image.new(image, mime_type, annotations: nil)
      else
        raise ArgumentError, "No content to render"
      end
    end
  end
end

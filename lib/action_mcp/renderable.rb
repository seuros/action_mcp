# frozen_string_literal: true

module ActionMCP
  # Module for rendering content.
  module Renderable
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

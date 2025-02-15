# frozen_string_literal: true

module ActionMCP
  module Renderable
    def render_text(text)
      Content::Text.new(text)
    end

    def render_audio(data, mime_type)
      Content::Audio.new(data, mime_type)
    end

    def render_image(data, mime_type)
      Content::Image.new(data, mime_type)
    end

    def render_resource(uri, mime_type, text: nil, blob: nil)
      Content::Resource.new(uri, mime_type, text: text, blob: blob)
    end

    def render_error(errors)
      {
        isError: true,
        content: errors.map { |error| render_text(error) }
      }
    end
  end
end

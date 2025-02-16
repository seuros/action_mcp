# frozen_string_literal: true

module ActionMCP
  # Module for rendering content.
  module Renderable
    # Renders text content.
    #
    # @param text [String] The text to render.
    # @return [Content::Text] The rendered text content.
    def render_text(text)
      Content::Text.new(text)
    end

    # Renders audio content.
    #
    # @param data [String] The audio data.
    # @param mime_type [String] The MIME type of the audio data.
    # @return [Content::Audio] The rendered audio content.
    def render_audio(data, mime_type)
      Content::Audio.new(data, mime_type)
    end

    # Renders image content.
    #
    # @param data [String] The image data.
    # @param mime_type [String] The MIME type of the image data.
    # @return [Content::Image] The rendered image content.
    def render_image(data, mime_type)
      Content::Image.new(data, mime_type)
    end

    # Renders a resource.
    #
    # @param uri [String] The URI of the resource.
    # @param mime_type [String] The MIME type of the resource.
    # @param text [String, nil] The text associated with the resource.
    # @param blob [String, nil] The blob associated with the resource.
    # @return [Content::Resource] The rendered resource content.
    def render_resource(uri, mime_type, text: nil, blob: nil)
      Content::Resource.new(uri, mime_type, text: text, blob: blob)
    end

    # Renders an error.
    #
    # @param errors [Array<String>] The errors to render.
    # @return [Hash] A hash containing the error information.
    def render_error(errors)
      {
        isError: true,
        content: errors.map { |error| render_text(error) }
      }
    end
  end
end

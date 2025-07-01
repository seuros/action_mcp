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

    # Renders a resource link for Model Context Protocol responses.
    #
    # @param uri [String] The URI of the resource
    # @param name [String, nil] Optional name for the resource
    # @param description [String, nil] Optional description
    # @param mime_type [String, nil] Optional MIME type
    # @param annotations [Hash, nil] Optional annotations
    #
    # @return [Content::ResourceLink] The rendered resource link object
    #
    # @example Render a resource link
    #   render_resource_link(uri: "file:///path/to/file.txt", name: "Example File")
    #
    def render_resource_link(uri:, name: nil, description: nil, mime_type: nil, annotations: nil)
      Content::ResourceLink.new(uri, name: name, description: description,
                                mime_type: mime_type, annotations: annotations)
    end
  end
end

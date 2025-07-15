# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class DummyRenderer
    include Renderable
  end

  class RenderableTest < Minitest::Test
    def setup
      @renderer = DummyRenderer.new
    end

    def test_render_text
      result = @renderer.render(text: "Hello, world!")
      assert_instance_of Content::Text, result
      assert_equal "Hello, world!", result.text
    end

    def test_render_audio
      result = @renderer.render(audio: "audio/path.mp3", mime_type: "audio/mpeg")
      assert_instance_of Content::Audio, result
      assert_equal "audio/path.mp3", result.data
      assert_equal "audio/mpeg", result.mime_type
    end

    def test_render_image
      result = @renderer.render(image: "image/path.png", mime_type: "image/png")
      assert_instance_of Content::Image, result
      assert_equal "image/path.png", result.data
      assert_equal "image/png", result.mime_type
    end

    def test_render_resource
      result = @renderer.render(resource: "file://paste/path.bin", mime_type: "application/octet-stream",
                                text: "Resource text", blob: "binarydata")
      assert_instance_of Content::Resource, result
      assert_equal "file://paste/path.bin", result.uri
      assert_equal "application/octet-stream", result.mime_type
      assert_equal "Resource text", result.text
      assert_equal "binarydata", result.blob
    end

    def test_render_raises_argument_error_when_no_content
      error = assert_raises(ArgumentError) { @renderer.render }
      assert_match(/No content to render/, error.message)
    end

    def test_render_audio_without_mime_type_raises
      error = assert_raises(ArgumentError) { @renderer.render(audio: "audio/path.mp3") }
      assert_match(/No content to render/, error.message)
    end

    def test_render_image_without_mime_type_raises
      error = assert_raises(ArgumentError) { @renderer.render(image: "image/path.png") }
      assert_match(/No content to render/, error.message)
    end
  end
end

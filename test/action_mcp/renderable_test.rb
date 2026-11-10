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

    { audio: [ Content::Audio, "audio/mpeg" ], image: [ Content::Image, "image/png" ] }.each do |kind, (klass, mime_type)|
      define_method(:"test_render_#{kind}") do
        data = Base64.strict_encode64("#{kind} data")
        result = @renderer.render(kind => data, mime_type: mime_type)
        assert_instance_of klass, result
        assert_equal data, result.data
        assert_equal mime_type, result.mime_type
      end
    end

    def test_render_resource
      blob = Base64.strict_encode64("binary data")
      result = @renderer.render(resource: "file://paste/path.bin", mime_type: "application/octet-stream",
                                blob: blob)
      assert_instance_of Content::Resource, result
      assert_equal "file://paste/path.bin", result.uri
      assert_equal "application/octet-stream", result.mime_type
      assert_nil result.text
      assert_equal blob, result.blob
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

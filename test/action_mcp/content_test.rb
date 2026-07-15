# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Content
    class ContentTest < ActiveSupport::TestCase
      test "Audio content behaves as expected" do
        data = Base64.strict_encode64("audio data")
        mime_type = "audio/mp3"
        audio = Audio.new(data, mime_type)

        # Verify attributes and type
        assert_equal "audio", audio.type
        assert_equal data, audio.data
        assert_equal mime_type, audio.mime_type

        # Verify to_h output
        expected = { type: "audio", data: data, mimeType: mime_type }
        assert_equal expected, audio.to_h
      end

      test "Audio content supports annotations" do
        data = Base64.strict_encode64("audio data")
        mime_type = "audio/mp3"
        annotations = { "audience" => [ "user" ], "priority" => 1 }
        audio = Audio.new(data, mime_type, annotations: annotations)
        expected = { type: "audio", data: data, mimeType: mime_type, annotations: annotations }
        assert_equal annotations, audio.annotations
        assert_equal expected, audio.to_h
      end

      test "Image content behaves as expected" do
        data = Base64.strict_encode64("image data")
        mime_type = "image/png"
        image = Image.new(data, mime_type)

        # Verify attributes and type
        assert_equal "image", image.type
        assert_equal data, image.data
        assert_equal mime_type, image.mime_type

        # Verify to_h output
        expected = { type: "image", data: data, mimeType: mime_type }
        assert_equal expected, image.to_h
      end

      test "Image content supports annotations" do
        data = Base64.strict_encode64("image data")
        mime_type = "image/png"
        annotations = { "audience" => [ "assistant" ], "priority" => 0.5 }
        image = Image.new(data, mime_type, annotations: annotations)
        expected = { type: "image", data: data, mimeType: mime_type, annotations: annotations }
        assert_equal annotations, image.annotations
        assert_equal expected, image.to_h
      end

      test "Resource content behaves as expected with various configurations" do
        uri = "http://example.com/resource"
        mime_type = "application/pdf"

        assert_raises(ArgumentError) { Resource.new(uri, mime_type) }

        # With text only
        text_content = "Optional text"
        resource_with_text = Resource.new(uri, mime_type, text: text_content)
        expected_with_text = { type: "resource", resource: { uri: uri, mimeType: mime_type, text: text_content } }
        assert_equal expected_with_text, resource_with_text.to_h

        # With blob only
        blob_content = Base64.strict_encode64("blob")
        resource_with_blob = Resource.new(uri, mime_type, blob: blob_content)
        expected_with_blob = { type: "resource", resource: { uri: uri, mimeType: mime_type, blob: blob_content } }
        assert_equal expected_with_blob, resource_with_blob.to_h

        assert_raises(ArgumentError) do
          Resource.new(uri, mime_type, text: text_content, blob: blob_content)
        end

        # meta is emitted on the inner resource hash as `_meta`, not the outer envelope
        meta = { ui: { prefersBorder: true } }
        resource_with_meta = Resource.new(uri, mime_type, text: text_content, meta: meta)
        assert_equal meta, resource_with_meta.to_h[:resource][:_meta]
        refute resource_with_meta.to_h.key?(:_meta)
      end

      test "Resource content supports annotations" do
        uri = "http://example.com/resource"
        mime_type = "application/pdf"
        annotations = { "audience" => [ "user" ], "priority" => 1 }
        resource = Resource.new(uri, mime_type, text: "contents", annotations: annotations)
        expected = {
          type: "resource",
          annotations: annotations,
          resource: { uri: uri, mimeType: mime_type, text: "contents" }
        }
        assert_equal annotations, resource.annotations
        assert_equal expected, resource.to_h
      end

      test "Text content behaves as expected" do
        text_content = "Hello, World!"
        text = Text.new(text_content)

        # Verify attributes and type
        assert_equal "text", text.type
        assert_equal text_content, text.text

        # Verify to_h output
        expected = { type: "text", text: text_content }
        assert_equal expected, text.to_h

        # Verify to_json returns valid JSON matching to_h
        parsed = MultiJson.load(text.to_json, symbolize_keys: true)
        assert_equal expected, parsed
      end

      test "Text content supports annotations" do
        text_content = "Hello, World!"
        annotations = { "audience" => [ "assistant" ], "priority" => 0.5 }
        text = Text.new(text_content, annotations: annotations)
        expected = { type: "text", text: text_content, annotations: annotations }
        assert_equal annotations, text.annotations
        assert_equal expected, text.to_h
      end

      test "ResourceLink requires and serializes its resource name" do
        assert_raises(ArgumentError) do
          ResourceLink.new("file:///report.txt", name: "")
        end

        link = ResourceLink.new("file:///report.txt", name: "report.txt")
        assert_equal(
          { type: "resource_link", uri: "file:///report.txt", name: "report.txt" },
          link.to_h
        )
      end

      test "binary content requires base64 data and string MIME types" do
        assert_raises(ArgumentError) { Image.new("not base64", "image/png") }
        assert_raises(ArgumentError) { Image.new(Base64.strict_encode64("image"), nil) }
        assert_raises(ArgumentError) { Audio.new("not base64", "audio/mpeg") }
        assert_raises(ArgumentError) { Audio.new(Base64.strict_encode64("audio"), 123) }
      end

      test "annotations follow the stable audience and priority schema" do
        assert_raises(ArgumentError) { Text.new("hello", annotations: []) }
        assert_raises(ArgumentError) { Text.new("hello", annotations: { audience: [ "system" ] }) }
        assert_raises(ArgumentError) { Text.new("hello", annotations: { priority: 1.1 }) }

        text = Text.new("hello", annotations: { audience: %w[user assistant], priority: 0 })
        assert_equal({ audience: %w[user assistant], priority: 0 }, text.annotations)
      end

      test "embedded resources require absolute URIs valid base64 and object metadata" do
        assert_raises(ArgumentError) { Resource.new("relative/path", text: "body") }
        assert_raises(ArgumentError) { Resource.new("file:///blob", blob: "not base64") }
        assert_raises(ArgumentError) { Resource.new("file:///text", text: "body", meta: []) }
      end

      test "resource links validate optional wire fields and URI format" do
        assert_raises(ArgumentError) { ResourceLink.new("relative/path", name: "report") }
        assert_raises(ArgumentError) { ResourceLink.new("file:///report", name: "report", description: 1) }
        assert_raises(ArgumentError) { ResourceLink.new("file:///report", name: "report", mime_type: {}) }
      end

      test "serialization catches invalid mutation after construction" do
        image = Image.new(Base64.strict_encode64("image"), "image/png")
        image.data.replace("not base64")

        assert_raises(ArgumentError) { image.to_h }
      end
    end
  end
end

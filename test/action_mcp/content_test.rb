# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Content
    class ContentTest < ActiveSupport::TestCase
      test "Audio content behaves as expected" do
        data = "base64encodedaudiodata"
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
        data = "base64encodedaudiodata"
        mime_type = "audio/mp3"
        annotations = { "audience" => [ "user" ], "priority" => 1 }
        audio = Audio.new(data, mime_type, annotations: annotations)
        expected = { type: "audio", data: data, mimeType: mime_type, annotations: annotations }
        assert_equal annotations, audio.annotations
        assert_equal expected, audio.to_h
      end

      test "Image content behaves as expected" do
        data = "base64encodedimagedata"
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
        data = "base64encodedimagedata"
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

        # Without optional text or blob
        resource = Resource.new(uri, mime_type)
        expected = { type: "resource", uri: uri, mimeType: mime_type }
        assert_equal expected, resource.to_h

        # With text only
        text_content = "Optional text"
        resource_with_text = Resource.new(uri, mime_type, text: text_content)
        expected_with_text = { type: "resource", uri: uri, mimeType: mime_type, text: text_content }
        assert_equal expected_with_text, resource_with_text.to_h

        # With blob only
        blob_content = "base64encodedblob"
        resource_with_blob = Resource.new(uri, mime_type, blob: blob_content)
        expected_with_blob = { type: "resource", uri: uri, mimeType: mime_type, blob: blob_content }
        assert_equal expected_with_blob, resource_with_blob.to_h

        # With both text and blob
        resource_full = Resource.new(uri, mime_type, text: text_content, blob: blob_content)
        expected_full = { type: "resource", uri: uri, mimeType: mime_type, text: text_content, blob: blob_content }
        assert_equal expected_full, resource_full.to_h
      end

      test "Resource content supports annotations" do
        uri = "http://example.com/resource"
        mime_type = "application/pdf"
        annotations = { "audience" => [ "user" ], "priority" => 1 }
        resource = Resource.new(uri, mime_type, annotations: annotations)
        expected = { type: "resource", uri: uri, mimeType: mime_type, annotations: annotations }
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
    end
  end
end

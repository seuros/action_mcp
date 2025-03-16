# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ToolResponseTest < ActiveSupport::TestCase
    setup do
      @response = ToolResponse.new
      @text_content = Content::Text.new("Hello world")
      @image_content = Content::Image.new("base64data", "image/png")
    end

    test "initializes with empty contents and no error" do
      assert_empty @response.contents
      assert_not @response.is_error
    end

    test "add appends content to contents array" do
      returned = @response.add(@text_content)

      assert_equal 1, @response.size
      assert_equal @text_content, @response.contents.first
      assert_equal @text_content, returned, "should return the added content"
    end

    test "mark_as_error! sets is_error to true" do
      result = @response.mark_as_error!

      assert @response.is_error
      assert_equal @response, result, "should return self for chaining"
    end

    test "to_h returns correct structure" do
      @response.add(@text_content)
      @response.add(@image_content)

      # Text content should have {type: "text", text: "Hello world"}
      # Image content should have {type: "image", data: "base64data", mimeType: "image/png"}
      expected = {
        content: [
          { type: "text", text: "Hello world" },
          { type: "image", data: "base64data", mimeType: "image/png" }
        ],
        isError: false
      }

      assert_equal expected, @response.to_h
    end

    test "to_h with error flag" do
      @response.add(@text_content)
      @response.mark_as_error!

      expected = {
        content: [ { type: "text", text: "Hello world" } ],
        isError: true
      }

      assert_equal expected, @response.to_h
    end

    test "as_json is alias of to_h" do
      @response.add(@text_content)

      assert_equal @response.to_h, @response.as_json
    end

    test "to_json returns valid JSON string" do
      @response.add(@text_content)

      expected = {
        content: [ { type: "text", text: "Hello world" } ],
        isError: false
      }.to_json

      assert_equal expected, @response.to_json
    end

    test "equality with hash" do
      @response.add(@text_content)

      expected_hash = {
        content: [ { type: "text", text: "Hello world" } ],
        isError: false
      }

      assert_equal expected_hash, @response.to_h
      assert @response == expected_hash
    end

    test "equality with another tool response" do
      @response.add(@text_content)

      other_response = ToolResponse.new
      other_response.add(@text_content)

      assert_equal other_response, @response
      assert @response == other_response
    end

    test "inequality when contents differ" do
      @response.add(@text_content)

      other_response = ToolResponse.new
      other_response.add(@image_content)

      assert_not_equal other_response, @response
      assert @response != other_response
    end

    test "inequality when error status differs" do
      @response.add(@text_content)

      other_response = ToolResponse.new
      other_response.add(@text_content)
      other_response.mark_as_error!

      assert_not_equal other_response, @response
      assert @response != other_response
    end

    test "delegates enumerable methods to contents" do
      @response.add(@text_content)
      @response.add(@image_content)

      assert_equal 2, @response.size
      assert_equal [ @text_content, @image_content ], @response.map { |c| c }
      assert_equal @text_content, @response.find { |c| c.is_a?(Content::Text) }
    end

    test "eql? matches == behavior" do
      @response.add(@text_content)

      other_response = ToolResponse.new
      other_response.add(@text_content)

      assert @response.eql?(other_response)

      other_response.mark_as_error!
      assert_not @response.eql?(other_response)
    end

    test "hash implementation for hash key usage" do
      @response.add(@text_content)

      duplicate = ToolResponse.new
      duplicate.add(@text_content)

      different = ToolResponse.new
      different.add(@image_content)

      hash = { @response => "original" }
      hash[duplicate] = "duplicate"
      hash[different] = "different"

      assert_equal 2, hash.size
      assert_equal "duplicate", hash[@response]
    end

    test "inspect returns readable representation" do
      @response.add(@text_content)

      # The actual format might differ depending on how Content::Text#inspect is implemented
      assert_match(/#<ActionMCP::ToolResponse content: \[.*\], isError: false>/, @response.inspect)
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class PromptResponseTest < ActiveSupport::TestCase
    setup do
      @response = PromptResponse.new
      @text_content = Content::Text.new("Hello world")
      @image_content = Content::Image.new("base64data", "image/png")
    end

    test "initializes with empty messages" do
      assert_empty @response.messages
    end

    test "success? returns false when is_error is true" do
      assert @response.success?
      @response.mark_as_error!
      assert_not @response.success?
      assert @response.error?
    end

    test "add_message adds a message with role and content" do
      result = @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      assert_equal 1, @response.size
      assert_equal({ role: "user", content: { type: "text", text: "Hello" } }, @response.messages.first)
      assert_equal @response, result, "should return self for chaining"
    end

    test "add_content adds message with content object" do
      result = @response.add_content(@text_content, role: "user")

      assert_equal 1, @response.size
      assert_equal "user", @response.messages.first[:role]
      assert_equal @text_content.to_h, @response.messages.first[:content]
      assert_equal @response, result, "should return self for chaining"
    end

    test "to_h returns correct structure" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })
      @response.add_message(role: "assistant", content: { type: "text", text: "Hi there" })

      expected = {
        messages: [
          { role: "user", content: { type: "text", text: "Hello" } },
          { role: "assistant", content: { type: "text", text: "Hi there" } }
        ]
      }

      assert_equal expected, @response.to_h
    end

    test "as_json is alias of to_h" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      assert_equal @response.to_h, @response.as_json
    end

    test "to_json returns valid JSON string" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      expected = {
        messages: [
          { role: "user", content: { type: "text", text: "Hello" } }
        ]
      }.to_json

      assert_equal expected, @response.to_json
    end

    test "equality with hash" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      expected_hash = {
        messages: [
          { role: "user", content: { type: "text", text: "Hello" } }
        ]
      }

      assert_equal expected_hash, @response.to_h
      assert @response == expected_hash
    end

    test "equality with another prompt response" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      other_response = PromptResponse.new
      other_response.add_message(role: "user", content: { type: "text", text: "Hello" })

      assert_equal other_response, @response.to_h
      assert @response == other_response
    end

    test "inequality when messages differ" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      other_response = PromptResponse.new
      other_response.add_message(role: "assistant", content: { type: "text", text: "Hello" })

      assert_not_equal other_response, @response
      assert @response != other_response
    end

    test "delegates enumerable methods to messages" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })
      @response.add_message(role: "assistant", content: { type: "text", text: "Hi there" })

      assert_equal 2, @response.size

      roles = @response.map { |m| m[:role] }
      assert_equal %w[user assistant], roles

      user_message = @response.find { |m| m[:role] == "user" }
      assert_equal "Hello", user_message[:content][:text]
    end

    test "eql? matches == behavior" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      other_response = PromptResponse.new
      other_response.add_message(role: "user", content: { type: "text", text: "Hello" })

      assert @response.eql?(other_response)

      other_response = PromptResponse.new
      other_response.add_message(role: "assistant", content: { type: "text", text: "Hello" })

      assert_not @response.eql?(other_response)
    end

    test "hash implementation for hash key usage" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      duplicate = PromptResponse.new
      duplicate.add_message(role: "user", content: { type: "text", text: "Hello" })

      different = PromptResponse.new
      different.add_message(role: "assistant", content: { type: "text", text: "Hello" })

      hash = { @response => "original" }
      hash[duplicate] = "duplicate"
      hash[different] = "different"

      assert_equal 2, hash.size
      assert_equal "duplicate", hash[@response]
    end

    test "inspect returns readable representation" do
      @response.add_message(role: "user", content: { type: "text", text: "Hello" })

      expected = '#<ActionMCP::PromptResponse messages: [{role: "user", content: {type: "text", text: "Hello"}}]>'
      assert_equal expected, @response.inspect
    end
  end
end

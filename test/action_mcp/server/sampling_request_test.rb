# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class SamplingRequestTest < ActiveSupport::TestCase
      def setup
        reset_defaults

        SamplingRequest.configure do |config|
          config.messages [
            {
              role: "user",
              content: ActionMCP::Content::Text.new(
                "Analyze the code files in the /project directory", annotations: nil
              )
            }
          ]
          config.system_prompt "You are a senior software engineer"
          config.include_context "thisServer"
          config.model_hints [ "claude-3-opus" ]
          config.intelligence_priority 0.9
          config.max_tokens 500
          config.temperature 0.7
        end
      end

      def teardown
        reset_defaults
      end

      test "initializes with configured defaults" do
        request = SamplingRequest.new
        hash = request.to_h

        assert_equal 1, hash[:messages].length, "Expected 1 message"
        assert_equal "user", hash[:messages][0][:role], "Expected role to be 'user'"
        assert_equal "Analyze the code files in the /project directory",
                     hash[:messages][0][:content][:text], "Expected correct message content"
        assert_equal "You are a senior software engineer",
                     hash[:systemPrompt], "Expected correct system prompt"
        assert_equal "thisServer", hash[:includeContext], "Expected correct context"
        assert_equal [ { name: "claude-3-opus" } ], hash[:modelPreferences][:hints], "Expected correct model hints"
        assert_equal 0.9, hash[:modelPreferences][:intelligencePriority], "Expected correct intelligence priority"
        assert_equal 500, hash[:maxTokens], "Expected correct max tokens"
        assert_equal 0.7, hash[:temperature], "Expected correct temperature"
      end

      test "overrides configured defaults per request" do
        custom_request = SamplingRequest.new do |req|
          req.add_message("Review my Ruby code for ways to make it look Haskell")
          req.system_prompt = "You are a Ruby reviewer"
          req.max_tokens = 1000
        end
        hash = custom_request.to_h

        assert_equal 2, hash[:messages].length, "Expected 2 messages"
        assert_equal "Review my Ruby code for ways to make it look Haskell",
                     hash[:messages][1][:content][:text], "Expected correct message content"
        assert_equal "user", hash[:messages][1][:role], "Expected role to be 'user'"
        assert_equal "You are a Ruby reviewer",
                     hash[:systemPrompt], "Expected correct system prompt"
        assert_equal 1000, hash[:maxTokens], "Expected correct max tokens"
        # Check that unchanged defaults persist
        assert_equal "thisServer", hash[:includeContext], "Expected correct context"
        assert_equal 0.7, hash[:temperature], "Expected correct temperature"
      end

      test "rejects roles outside user and assistant" do
        request = SamplingRequest.new do |req|
          req.add_message("System message", role: "system")
        end

        error = assert_raises(ArgumentError) { request.to_h }
        assert_match(/MCP 2025-11-25/, error.message)
      end

      test "allows reconfiguration" do
        SamplingRequest.configure do |config|
          config.system_prompt "You are a coding reviewer"
          config.model_hints [ "claude-3-opus" ]
        end

        request = SamplingRequest.new
        hash = request.to_h

        assert_equal "You are a coding reviewer",
                     hash[:systemPrompt], "Expected correct system prompt"
        assert_equal [ { name: "claude-3-opus" } ],
                     hash[:modelPreferences][:hints], "Expected correct model hints"
        # Verify other defaults remain from original setup
        assert_equal "thisServer", hash[:includeContext], "Expected correct context"
        assert_equal 0.9, hash[:modelPreferences][:intelligencePriority], "Expected correct intelligence priority"
      end

      test "has valid defaults without configuration" do
        reset_defaults

        hash = SamplingRequest.new.to_h

        assert_equal [], hash[:messages]
        assert_equal 500, hash[:maxTokens]
        assert_equal 0.7, hash[:temperature]
      end

      test "serializes released sampling tool fields" do
        request = SamplingRequest.new do |req|
          req.tools = [ { name: "lookup", inputSchema: { type: "object" } } ]
          req.tool_choice = { mode: "required" }
          req.stop_sequences = [ "done" ]
          req.metadata = { provider: "test" }
          req.task = { ttl: 60_000 }
        end

        hash = request.to_h

        assert_equal "lookup", hash[:tools].first[:name]
        assert_equal({ mode: "required" }, hash[:toolChoice])
        assert_equal({ ttl: 60_000 }, hash[:task])
      end

      test "rejects fractional task ttl" do
        request = SamplingRequest.new do |req|
          req.task = { ttl: 1.5 }
        end

        error = assert_raises(ArgumentError) { request.to_h }
        assert_match(/MCP 2025-11-25/, error.message)
      end

      test "accepts balanced tool use turns with complete results in any order" do
        messages = [
          text_message("Check both cities", role: "user"),
          {
            role: "assistant",
            content: [
              { type: "text", text: "I will check both." },
              tool_use("paris"),
              tool_use("london")
            ]
          },
          {
            role: "user",
            content: [
              tool_result(
                "london",
                content: [
                  {
                    type: "resource_link",
                    name: "forecast",
                    uri: "https://weather.example/london",
                    annotations: { audience: [ "assistant" ], priority: 0.8 }
                  }
                ]
              ),
              tool_result(
                "paris",
                content: [
                  { type: "image", data: "aW1hZ2U=", mimeType: "image/png" },
                  {
                    type: "resource",
                    resource: {
                      uri: "file:///tmp/forecast.txt",
                      text: "Clear"
                    }
                  }
                ]
              )
            ]
          },
          text_message("Both forecasts are ready", role: "assistant")
        ]

        hash = request_with_messages(messages).to_h

        assert_equal %w[london paris], hash[:messages][2][:content].map { |result| result[:toolUseId] }
      end

      test "rejects tool result messages mixed with other content" do
        messages = [
          { role: "assistant", content: tool_use("call-1") },
          {
            role: "user",
            content: [
              tool_result("call-1"),
              { type: "text", text: "Result follows" }
            ]
          }
        ]

        assert_invalid_messages(messages, /containing only results/)
      end

      test "requires tool results immediately after the assistant tool uses" do
        messages = [
          { role: "assistant", content: tool_use("call-1") },
          text_message("Not a result", role: "assistant"),
          { role: "user", content: tool_result("call-1") }
        ]

        assert_invalid_messages(messages, %r{/messages/1})
      end

      test "rejects tool uses missing a following result message" do
        messages = [ { role: "assistant", content: tool_use("call-1") } ]

        assert_invalid_messages(messages, /missing their next user results/)
      end

      test "rejects unmatched tool results" do
        messages = [ { role: "user", content: tool_result("call-1") } ]

        assert_invalid_messages(messages, /do not match a preceding tool use/)
      end

      test "requires every tool use ID to have exactly one matching result" do
        missing = [
          { role: "assistant", content: [ tool_use("call-1"), tool_use("call-2") ] },
          { role: "user", content: tool_result("call-1") }
        ]
        unexpected = [
          { role: "assistant", content: tool_use("call-1") },
          { role: "user", content: tool_result("call-2") }
        ]
        duplicate = [
          { role: "assistant", content: [ tool_use("call-1"), tool_use("call-2") ] },
          { role: "user", content: [ tool_result("call-1"), tool_result("call-1") ] }
        ]

        assert_invalid_messages(missing, /exactly match/)
        assert_invalid_messages(unexpected, /exactly match/)
        assert_invalid_messages(duplicate, /must not contain duplicates/)
      end

      test "requires unique tool use IDs across the conversation" do
        duplicate_set = [
          {
            role: "assistant",
            content: [ tool_use("call-1"), tool_use("call-1") ]
          }
        ]
        reused = [
          { role: "assistant", content: tool_use("call-1") },
          { role: "user", content: tool_result("call-1") },
          { role: "assistant", content: tool_use("call-1") }
        ]

        assert_invalid_messages(duplicate_set, /must not contain duplicates/)
        assert_invalid_messages(reused, /is not unique/)
      end

      test "enforces sampling roles for tool uses and results" do
        user_tool_use = [ { role: "user", content: tool_use("call-1") } ]
        assistant_result = [ { role: "assistant", content: tool_result("call-1") } ]

        assert_invalid_messages(user_tool_use, /tool uses must be in an assistant message/)
        assert_invalid_messages(assistant_result, /must be user messages/)
      end

      test "validates top-level sampling content base64 and annotations" do
        invalid_messages = [
          [
            {
              role: "user",
              content: { type: "image", data: "not base64!", mimeType: "image/png" }
            }
          ],
          [
            {
              role: "user",
              content: {
                type: "text",
                text: "Review",
                annotations: { audience: [ "developer" ] }
              }
            }
          ]
        ]

        invalid_messages.each do |messages|
          assert_invalid_messages(messages, /MCP 2025-11-25/)
        end
      end

      test "validates nested tool result content against shared content schemas" do
        invalid_content = [
          [ { type: "audio", data: "not base64!", mimeType: "audio/wav" } ],
          [ { type: "text", text: "result", annotations: { priority: 2 } } ],
          [ { type: "resource_link", name: "result", uri: "relative/path" } ],
          [
            {
              type: "resource",
              resource: { uri: "file:///tmp/result.bin", blob: "not base64!" }
            }
          ]
        ]

        invalid_content.each do |content|
          messages = [
            { role: "assistant", content: tool_use("call-1") },
            { role: "user", content: tool_result("call-1", content: content) }
          ]

          assert_invalid_messages(messages, /MCP 2025-11-25/)
        end
      end

      test "validates all released tool descriptor fields" do
        valid_tool = {
          name: "lookup",
          inputSchema: { type: "object" }
        }
        invalid_fields = [
          { annotations: { readOnlyHint: "yes" } },
          { execution: { taskSupport: "sometimes" } },
          { icons: [ { src: "relative/icon.png" } ] },
          { inputSchema: { type: "object", required: "query" } },
          { outputSchema: { type: "array" } }
        ]

        invalid_fields.each do |fields|
          request = SamplingRequest.new do |req|
            req.tools = [ valid_tool.merge(fields) ]
          end

          assert_raises(ArgumentError) { request.to_h }
        end
      end

      test "validates progress tokens in request metadata" do
        request = SamplingRequest.new do |req|
          req.request_meta = { progressToken: [ "invalid" ] }
        end

        error = assert_raises(ArgumentError) { request.to_h }
        assert_match(%r{/_meta/progressToken}, error.message)
      end

      private

      def request_with_messages(messages)
        SamplingRequest.new { |request| request.messages = messages }
      end

      def assert_invalid_messages(messages, pattern)
        error = assert_raises(ArgumentError) { request_with_messages(messages).to_h }
        assert_match(pattern, error.message)
      end

      def text_message(text, role:)
        { role: role, content: { type: "text", text: text } }
      end

      def tool_use(id)
        { type: "tool_use", id: id, name: "lookup", input: {} }
      end

      def tool_result(id, content: [ { type: "text", text: "done" } ])
        { type: "tool_result", toolUseId: id, content: content }
      end

      def reset_defaults
        SamplingRequest.instance_variables.each do |ivar|
          SamplingRequest.remove_instance_variable(ivar)
        end
      end
    end
  end
end

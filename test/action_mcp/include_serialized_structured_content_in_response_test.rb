# frozen_string_literal: true

require "test_helper"

class ActionMCP::IncludeSerializedStructuredContentInResponseTest < ActiveSupport::TestCase
  setup do
    @request = ActionDispatch::Request.new({})

    @tool_class = Class.new(ApplicationMCPTool) do
      tool_name "serialized_structured_content_tool"
      description "Tool with serialized structured content"

      output_schema do
        property :name, type: "string", required: true
        property :count, type: "number", required: true
      end

      def perform
        render structured: { name: "test", count: 42 }
      end
    end
  end

  teardown do
    ActionMCP.configuration.include_serialized_structured_content_in_response = false
  end

  test "sends serialized structured content in response" do
    ActionMCP.configuration.include_serialized_structured_content_in_response = true

    tool = @tool_class.new
    result = tool.call

    assert_equal([ { type: "text", text: '{"name":"test","count":42}' } ], result.contents)
    assert_equal({ name: "test", count: 42 }, result.structured_content)
  end

  test "does not send serialized structured content in response when not enabled" do
    ActionMCP.configuration.include_serialized_structured_content_in_response = false

    tool = @tool_class.new
    result = tool.call

    assert_equal([], result.contents)
    assert_equal({ name: "test", count: 42 }, result.structured_content)
  end
end

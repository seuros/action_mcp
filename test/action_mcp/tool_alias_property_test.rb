# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolAliasPropertyTest < ActiveSupport::TestCase
  test "alias_property accepts alternate parameter names for the same property" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "alias_property_message"
      description "Tool with aliased thread parameter"

      property :thread_id, type: "string", required: true
      alias_property :root_id, :thread_id

      def perform
        render text: thread_id
      end
    end

    tool = tool_class.new(root_id: "thread-123")

    assert tool.valid?
    assert_equal "thread-123", tool.thread_id
    assert_equal "thread-123", tool.root_id
    assert_equal({ "thread_id" => "thread-123" }, tool.attributes)

    response = tool_class.call(root_id: "thread-123")

    refute response.error?
    assert_equal "thread-123", response.contents.first.text
  end

  test "alias_property keeps aliases out of additional_params" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "alias_property_additional_params"
      description "Tool with aliased params and additional params"

      property :thread_id, type: "string", required: true
      alias_property :root_id, :thread_id
      additional_properties true
    end

    tool = tool_class.new("root_id" => "thread-123", "metadata" => "value")

    assert_equal "thread-123", tool.thread_id
    assert_equal({ "metadata" => "value" }, tool.additional_params)
    assert_includes tool_class.schema_property_keys, "root_id"
  end

  test "alias_property validates aliased values against the target property type" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "alias_property_type_validation"
      description "Tool with numeric aliased param"

      property :thread_id, type: "number", required: true
      alias_property :root_id, :thread_id
    end

    tool = tool_class.from_wire(root_id: "not-a-number")

    refute tool.valid?
    assert_match(%r{/root_id}, tool.errors.full_messages.join)
    assert_match(/not a number/, tool.errors.full_messages.join)
  end

  test "alias_property rejects conflicting canonical and alias values" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "alias_property_conflict"
      description "Tool with conflicting aliased params"

      property :thread_id, type: "string", required: true
      alias_property :root_id, :thread_id
    end

    tool = tool_class.new(thread_id: "thread-123", root_id: "thread-456")

    refute tool.valid?
    assert_match(/conflicting values/, tool.errors.full_messages.join)
    assert_match(/thread_id/, tool.errors.full_messages.join)
    assert_match(/root_id/, tool.errors.full_messages.join)
  end

  test "alias_property requires an existing target property" do
    error = assert_raises(ArgumentError) do
      Class.new(ActionMCP::Tool) do
        tool_name "alias_property_unknown_target"
        description "Tool with invalid alias"

        alias_property :root_id, :thread_id
      end
    end

    assert_match(/unknown property 'thread_id'/, error.message)
  end

  test "property cannot reuse an existing alias name" do
    error = assert_raises(ArgumentError) do
      Class.new(ActionMCP::Tool) do
        tool_name "alias_property_reused_alias"
        description "Tool with duplicate alias and property"

        property :thread_id, type: "string", required: true
        alias_property :root_id, :thread_id
        property :root_id, type: "string"
      end
    end

    assert_match(/already defined as an alias/, error.message)
  end

  test "alias_property advertises both accepted input names" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "alias_property_schema"
      description "Tool with canonical schema"

      property :thread_id, type: "string", required: true
      alias_property :root_id, :thread_id
    end

    schema = tool_class.to_h[:inputSchema]

    assert_includes schema[:properties], "thread_id"
    assert_includes schema[:properties], "root_id"
    assert_nil schema[:required]
    alternatives = schema.fetch(:allOf).first.fetch(:anyOf)
    assert_equal [ [ "thread_id" ], [ "root_id" ] ], alternatives.pluck(:required)
  end
end

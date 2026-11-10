# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolAliasPropertyTest < ActiveSupport::TestCase
  test "alias_property accepts alternate parameter names for the same property" do
    tool = ThreadReplyTool.new(root_id: "thread-123")

    assert tool.valid?
    assert_equal "thread-123", tool.thread_id
    assert_equal "thread-123", tool.root_id
    assert_equal "thread-123", tool.attributes["thread_id"]
    refute tool.attributes.key?("root_id")

    response = ThreadReplyTool.call(root_id: "thread-123")

    refute response.error?
    assert_equal "thread-123", response.contents.first.text
  end

  test "alias_property keeps aliases out of additional_params" do
    tool = ThreadReplyTool.new("root_id" => "thread-123", "metadata" => "value")

    assert_equal "thread-123", tool.thread_id
    assert_equal({ "metadata" => "value" }, tool.additional_params)
    assert_includes ThreadReplyTool.schema_property_keys, "root_id"
  end

  test "alias_property validates aliased values against the target property type" do
    tool = ThreadReplyTool.from_wire(thread_id: "thread-123", seq: "not-a-number")

    refute tool.valid?
    assert_match(%r{/seq}, tool.errors.full_messages.join)
    assert_match(/not a number/, tool.errors.full_messages.join)
  end

  test "alias_property rejects conflicting canonical and alias values" do
    tool = ThreadReplyTool.new(thread_id: "thread-123", root_id: "thread-456")

    refute tool.valid?
    assert_match(/conflicting values/, tool.errors.full_messages.join)
    assert_match(/thread_id/, tool.errors.full_messages.join)
    assert_match(/root_id/, tool.errors.full_messages.join)
  end

  test "alias_property requires an existing target property" do
    error = assert_raises(ArgumentError) { ThreadReplyTool.alias_property :parent_id, :parent }

    assert_match(/unknown property 'parent'/, error.message)
    refute_includes ThreadReplyTool.schema_property_keys, "parent_id"
  end

  test "property cannot reuse an existing alias name" do
    error = assert_raises(ArgumentError) { ThreadReplyTool.property :root_id, type: "string" }

    assert_match(/already defined as an alias/, error.message)
    assert_equal "thread_id", ThreadReplyTool.canonical_property_name(:root_id)
  end

  test "alias_property advertises both accepted input names" do
    schema = ThreadReplyTool.to_h[:inputSchema]

    assert_includes schema[:properties], "thread_id"
    assert_includes schema[:properties], "root_id"
    assert_nil schema[:required]
    alternatives = schema.fetch(:allOf).first.fetch(:anyOf)
    assert_equal [ [ "thread_id" ], [ "root_id" ] ], alternatives.pluck(:required)
  end
end

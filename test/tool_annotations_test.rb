# frozen_string_literal: true

require "test_helper"

class ToolAnnotationsTest < ActiveSupport::TestCase
  # Tools with Read-Only annotations
  test "read_only annotation is mapped to readOnlyHint in tool schema" do
    tool_class = ExplosiveTool
    assert_equal true, tool_class._annotations["readOnlyHint"], "readOnlyHint should be set to true"

    # Check to_h output
    tool_hash = tool_class.to_h
    assert_includes tool_hash[:annotations].keys, "readOnlyHint"
    assert_equal true, tool_hash[:annotations]["readOnlyHint"]
  end

  # Tools with Destructive annotations
  test "destructive annotation is mapped to destructiveHint in tool schema" do
    # Create a test class with destructive annotation
    class DestructiveTestTool < ActionMCP::Tool
      tool_name "destructive_test"
      description "Test tool with destructive annotation"
      destructive
    end

    tool_class = DestructiveTestTool
    assert_equal true, tool_class._annotations["destructiveHint"], "destructiveHint should be set to true"

    # Check to_h output
    tool_hash = tool_class.to_h
    assert_includes tool_hash[:annotations].keys, "destructiveHint"
    assert_equal true, tool_hash[:annotations]["destructiveHint"]
  end

  # Tools with Idempotent annotations
  test "idempotent annotation is mapped to idempotentHint in tool schema" do
    tool_class = NumericArrayTool
    assert_equal true, tool_class._annotations["idempotentHint"], "idempotentHint should be set to true"

    # Check to_h output
    tool_hash = tool_class.to_h
    assert_includes tool_hash[:annotations].keys, "idempotentHint"
    assert_equal true, tool_hash[:annotations]["idempotentHint"]
  end

  # Tools with Open World annotations
  test "open_world annotation is mapped to openWorldHint in tool schema" do
    # Create a test class with open_world annotation
    class OpenWorldTestTool < ActionMCP::Tool
      tool_name "open_world_test"
      description "Test tool with open_world annotation"
      open_world
    end

    tool_class = OpenWorldTestTool
    assert_equal true, tool_class._annotations["openWorldHint"], "openWorldHint should be set to true"

    # Check to_h output
    tool_hash = tool_class.to_h
    assert_includes tool_hash[:annotations].keys, "openWorldHint"
    assert_equal true, tool_hash[:annotations]["openWorldHint"]
  end

  # Tools with Title annotations
  test "title annotation is included in tool schema" do
    # Create a test class with title annotation
    class TitleTestTool < ActionMCP::Tool
      tool_name "title_test"
      title "Title Test Tool"
      description "Test tool with title annotation"
    end

    tool_class = TitleTestTool
    assert_equal "Title Test Tool", tool_class._annotations["title"], "title should be 'Title Test Tool'"

    # Check to_h output
    tool_hash = tool_class.to_h
    assert_includes tool_hash[:annotations].keys, "title"
    assert_equal "Title Test Tool", tool_hash[:annotations]["title"]
  end

  # Test a tool with multiple annotations
  test "tools can have multiple annotations" do
    # Create a test class with multiple annotations
    class MultiAnnotationTestTool < ActionMCP::Tool
      tool_name "multi_annotation_test"
      title "Multi Annotation Tool"
      description "Test tool with multiple annotations"
      read_only
      idempotent
      destructive
      open_world
    end

    tool_class = MultiAnnotationTestTool
    tool_hash = tool_class.to_h

    assert_includes tool_hash[:annotations].keys, "readOnlyHint"
    assert_includes tool_hash[:annotations].keys, "idempotentHint"
    assert_includes tool_hash[:annotations].keys, "destructiveHint"
    assert_includes tool_hash[:annotations].keys, "openWorldHint"
    assert_includes tool_hash[:annotations].keys, "title"

    assert_equal true, tool_hash[:annotations]["readOnlyHint"]
    assert_equal true, tool_hash[:annotations]["idempotentHint"]
    assert_equal true, tool_hash[:annotations]["destructiveHint"]
    assert_equal true, tool_hash[:annotations]["openWorldHint"]
    assert_equal "Multi Annotation Tool", tool_hash[:annotations]["title"]
  end
end

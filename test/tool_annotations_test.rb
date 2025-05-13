# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ToolAnnotationsTest < ActiveSupport::TestCase
    class AnnotatedTool < Tool
      tool_name "annotated_tool"
      description "Tool with annotations"

      destructive true
      read_only false
      annotate :custom, "value"
    end

    class NonDestructiveTool < Tool
      tool_name "non_destructive_tool"
      description "Safe tool"

      destructive false
      read_only true
    end

    test "tool annotations are set correctly" do
      expected_annotations = {
        "destructive" => true,
        "readOnly" => false,
        "custom" => "value"
      }

      assert_equal expected_annotations, AnnotatedTool._annotations
    end

    test "tool.to_h includes annotations" do
      result = AnnotatedTool.to_h(protocol_version: "2025-03-26")

      assert result.key?(:annotations)
      assert_equal true, result[:annotations]["destructive"]
      assert_equal false, result[:annotations]["readOnly"]
      assert_equal "value", result[:annotations]["custom"]
    end

    test "tool.to_h includes annotations when no protocol specified" do
      result = AnnotatedTool.to_h

      assert result.key?(:annotations)
      assert_equal true, result[:annotations]["destructive"]
      assert_equal false, result[:annotations]["readOnly"]
      assert_equal "value", result[:annotations]["custom"]
    end

    test "convenience methods set correct annotations" do
      result = NonDestructiveTool.to_h(protocol_version: "2025-03-26")

      assert_equal false, result[:annotations]["destructive"]
      assert_equal true, result[:annotations]["readOnly"]
    end

    test "tools without annotations work correctly" do
      class PlainTool < Tool
        tool_name "plain_tool"
        description "Tool without annotations"
      end

      result = PlainTool.to_h(protocol_version: "2025-03-26")
      assert_not result.key?(:annotations)
    end
  end
end

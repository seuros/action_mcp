# frozen_string_literal: true

require "test_helper"

class SchemaValidationTest < ActiveSupport::TestCase
  def setup
    @tools = ActionMCP.tools.values
  end

  test "all tools generate valid JSON schemas" do
    @tools.each do |tool_class|
      next if tool_class.abstract?

      tool_def = tool_class.to_h
      schema = tool_def[:inputSchema]

      assert_not_nil schema, "Tool #{tool_class.name} should have inputSchema"
      assert_equal "object", schema[:type] || schema["type"],
                   "Tool #{tool_class.name} schema type should be 'object'"

      # Validate properties if present
      props = schema[:properties] || schema["properties"]
      if props
        assert props.is_a?(Hash),
               "Tool #{tool_class.name} properties should be a Hash"

        props.each do |prop_name, prop_def|
          assert prop_def.is_a?(Hash),
                 "Property #{prop_name} in #{tool_class.name} should be a Hash"

          # Check for valid types
          if prop_def["type"]
            valid_types = %w[string number integer boolean array object null]
            assert valid_types.include?(prop_def["type"]),
                   "Property #{prop_name} in #{tool_class.name} has invalid type: #{prop_def['type']}"
          end

          # Check array items
          next unless prop_def["type"] == "array" && prop_def["items"]

          assert prop_def["items"].is_a?(Hash),
                 "Array property #{prop_name} in #{tool_class.name} should have items as Hash"

          if prop_def["items"]["type"]
            assert valid_types.include?(prop_def["items"]["type"]),
                   "Array items type for #{prop_name} in #{tool_class.name} is invalid: #{prop_def['items']['type']}"
          end
        end
      end

      # Check required array
      required = schema[:required] || schema["required"]
      next unless required

      assert required.is_a?(Array),
             "Tool #{tool_class.name} required should be an Array"
      required.each do |req|
        assert req.is_a?(String),
               "Required property #{req} in #{tool_class.name} should be a String"
        assert props&.key?(req) || props&.key?(req.to_sym),
               "Required property #{req} in #{tool_class.name} is not defined in properties"
      end
    end
  end

  test "specific tool schemas are generated correctly" do
    # Test CalculateSumTool
    if defined?(CalculateSumTool)
      schema = CalculateSumTool.to_h[:inputSchema]

      assert_equal "object", schema[:type] || schema["type"]

      props = schema[:properties] || schema["properties"]

      # Properties could be keyed by strings or symbols
      a_prop = props["a"] || props[:a]
      b_prop = props["b"] || props[:b]

      assert a_prop, "a property should exist"
      assert b_prop, "b property should exist"

      assert_equal "number", a_prop["type"] || a_prop[:type]
      assert_equal "number", b_prop["type"] || b_prop[:type]
      assert_equal "The first number", a_prop["description"] || a_prop[:description]
      assert_equal "The second number", b_prop["description"] || b_prop[:description]

      assert_equal %w[a b], schema[:required] || schema["required"]
    end

    # Test AddTool
    if defined?(AddTool)
      schema = AddTool.to_h[:inputSchema]

      props = schema[:properties] || schema["properties"]
      x_prop = props["x"] || props[:x]
      y_prop = props["y"] || props[:y]

      assert x_prop, "x property should exist"
      assert y_prop, "y property should exist"
      assert_equal "number", x_prop["type"] || x_prop[:type]
      assert_equal "number", y_prop["type"] || y_prop[:type]
    end

    # Test UserInfoTool
    if defined?(UserInfoTool)
      schema = UserInfoTool.to_h[:inputSchema]

      props = schema[:properties] || schema["properties"]
      sensitive_prop = props["include_sensitive"] || props[:include_sensitive]

      assert sensitive_prop, "include_sensitive property should exist"
      assert_equal "boolean", sensitive_prop["type"] || sensitive_prop[:type]
    end
  end

  test "tools with collections generate proper array schemas" do
    props = GitHubCreateIssueTool.to_h[:inputSchema][:properties]
    labels = props["labels"]

    assert_equal "array", labels[:type]
    assert_equal "string", labels[:items][:type]
    assert_equal "Issue labels", labels[:description]
    assert_equal({ type: "array", items: { type: "number" } }, NumericArrayTool.to_h[:inputSchema][:properties]["numbers"])
  end

  test "prompts generate valid schemas" do
    prompts = ActionMCP.prompts.values

    prompts.each do |prompt_class|
      next if prompt_class.abstract?

      prompt_def = prompt_class.to_h

      assert_not_nil prompt_def[:name], "Prompt #{prompt_class.name} should have a name"

      next unless prompt_def[:arguments]

      prompt_def[:arguments].each do |arg|
        assert arg[:name].is_a?(String), "Argument name should be a String"
        assert [ true, false, nil ].include?(arg[:required]), "Argument required should be boolean or nil"
      end
    end
  end
end

# frozen_string_literal: true

# ======================================================================
#  test/action_mcp/to_h_contract_test.rb
#
#  The One Contract Test to rule them all — and bind them in the darkness.
#  This beast loads the “golden” `.to_h` outputs from YAML fixtures and
#  verifies that every public MCP artefact still walks the line.
#
#  •Fixture files live in test/fixtures/action_mcp/
#        ├─ tool_hashes.yml       ← all the pretend truth about tools
#        ├─ prompt_hashes.yml     ← prompts, pre-digested
#        └─ template_hashes.yml   ← the sacred template canon
#
#  •Adding a new tool / prompt / template?
#        1. Paste its YAML into the appropriate lore tome above.
#        2. Add the mapping from class to key in the lookup below.
#        3. No extra test file needed — you’re already covered. Bask in it.
# ======================================================================

require "test_helper"
require "minitest/spec"

class ToHContractTest < ActiveSupport::TestCase
  extend FixtureHelpers
  TOOL_FIXTURES = load_fixture("tool_hashes")
  PROMPT_FIXTURES = load_fixture("prompt_hashes")
  TEMPLATE_FIXTURES = load_fixture("template_hashes")

  # ----------------------------------------------------------------------
  # Tools
  # ----------------------------------------------------------------------
  {
    AddTool => "add",
    CalculateSumTool => "calculate_sum",
    CalculateSumWithPrecisionTool => "calculate_sum_with_precision",
    ExecuteCommandTool => "execute_command",
    AnalyzeCsvTool => "analyze_csv",
    GitHubCreateIssueTool => "create_github_issue",
    WeatherForecastTool => "weather_forecast",
    BoomTool => "boom" # still has a to_h
  }.each do |klass, key|
    class_name = klass.name
    describe "#{class_name} .to_h contract" do
      it "matches the tool fixture" do
        assert_equal TOOL_FIXTURES[key], klass.to_h.deep_stringify_keys,
                     "#{class_name}#to_h drifted from fixture"
      end
    end
  end

  # ----------------------------------------------------------------------
  # Prompts
  # ----------------------------------------------------------------------
  {
    AnalyzeCodePrompt => "analyze_code",
    SummarizeTextPrompt => "summarize_text",
    GreetingPrompt => "greeting",
    CarbonFootprintAssessmentPrompt => "carbon_footprint_assessment"
  }.each do |klass, key|
    class_name = klass.name
    describe "#{class_name} .to_h contract" do
      it "matches the prompt fixture" do
        assert_equal PROMPT_FIXTURES[key], klass.to_h.deep_stringify_keys,
                     "#{class_name}#to_h drifted from fixture"
      end
    end
  end

  # ----------------------------------------------------------------------
  # Resource templates
  # ----------------------------------------------------------------------
  {
    OrdersTemplate => "orders",
    ProductsTemplate => "products"
  }.each do |klass, key|
    class_name = klass.name
    describe "#{class_name} .to_h contract" do
      it "matches the template fixture" do
        assert_equal TEMPLATE_FIXTURES[key], klass.to_h.deep_stringify_keys,
                     "#{class_name}#to_h drifted from fixture"
      end
    end
  end
end

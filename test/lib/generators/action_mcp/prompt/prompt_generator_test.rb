# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/prompt/prompt_generator"

class PromptGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::PromptGenerator
  include GeneratorTestDestination

  def generated_prompt_path(name)
    generated_component_path(name, "prompt", "prompts")
  end


  test "generator creates prompt file with correct class name" do
    run_generator %w[MyCustom]
    assert_file generated_prompt_path("my_custom"), /class MyCustomPrompt < ApplicationMCPPrompt/
  end

  test "generator appends Prompt to class name if not present" do
    run_generator %w[Another]
    assert_file generated_prompt_path("another"), /class AnotherPrompt < ApplicationMCPPrompt/
  end

  test "generator does not double Prompt in class name" do
    run_generator %w[AlreadyPrompt]
    assert_file generated_prompt_path("already_prompt"), /class AlreadyPrompt < ApplicationMCPPrompt/
  end

  test "generator sets correct prompt name" do
    run_generator %w[TestAnalyzer]
    assert_file generated_prompt_path("test_analyzer"), /prompt_name "test-analyzer"/
  end

  test "generator removes Prompt suffix from prompt name" do
    run_generator %w[AnalyzerPrompt]
    assert_file generated_prompt_path("analyzer_prompt"), /prompt_name "analyzer"/
  end

  test "generator includes default description" do
    run_generator %w[TestPrompt]
    assert_file generated_prompt_path("test_prompt"), /description "Describe what this prompt does"/
  end

  test "generator creates proper file structure" do
    run_generator %w[CompleteTest]
    assert_file generated_prompt_path("complete_test") do |content|
      assert_match(/class CompleteTestPrompt < ApplicationMCPPrompt/, content)
      assert_match(/prompt_name "complete-test"/, content)
      assert_match(/description "Describe what this prompt does"/, content)
      assert_match(/argument :input, description: "Main input", required: true/, content)
      assert_match(/def perform/, content)
    end
  end
end

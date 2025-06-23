# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::InstallGenerator
  destination File.expand_path("../../../../../tmp/generator_test_output", __dir__)
  setup :prepare_destination

  test "generator creates application prompt file" do
    run_generator
    assert_file "app/mcp/prompts/application_mcp_prompt.rb" do |content|
      assert_match(/class ApplicationMCPPrompt < ActionMCP::Prompt/, content)
    end
  end

  test "generator creates application tool file" do
    run_generator
    assert_file "app/mcp/tools/application_mcp_tool.rb" do |content|
      assert_match(/class ApplicationMCPTool < ActionMCP::Tool/, content)
    end
  end

  test "generator creates application resource template file" do
    run_generator
    assert_file "app/mcp/resource_templates/application_mcp_res_template.rb" do |content|
      assert_match(/class ApplicationMCPResTemplate < ActionMCP::ResourceTemplate/, content)
    end
  end

  test "generator creates mcp configuration file" do
    run_generator
    assert_file "config/mcp.yml" do |content|
      assert_match(/shared:/, content)
      assert_match(/authentication:/, content)
      assert_match(/profiles:/, content)
      assert_match(/development:/, content)
      assert_match(/test:/, content)
      assert_match(/production:/, content)
    end
  end

  test "generator creates application gateway file" do
    run_generator
    assert_file "app/mcp/application_gateway.rb" do |content|
      assert_match(/class ApplicationGateway < ActionMCP::Gateway/, content)
    end
  end

  test "generator creates all expected directories" do
    run_generator
    assert_directory "app/mcp"
    assert_directory "app/mcp/prompts"
    assert_directory "app/mcp/tools"
    assert_directory "app/mcp/resource_templates"
    assert_directory "config"
  end

  test "generator shows installation instructions" do
    output = run_generator
    assert_match(/ActionMCP has been installed successfully!/, output)
    assert_match(/Files created:/, output)
    assert_match(/Configuration:/, output)
    assert_match(/Available adapters:/, output)
    assert_match(/Next steps:/, output)
  end
end

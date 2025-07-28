# frozen_string_literal: true

require "test_helper"
require "generators/action_mcp/identifier/identifier_generator"

class ActionMCP::Generators::IdentifierGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::IdentifierGenerator
  destination Rails.root.join("tmp/generator_test_output")
  setup :prepare_destination

  test "generates identifier with default options" do
    run_generator [ "MyAuth", "--auth-method=api_key" ]

    assert_file "app/mcp/identifiers/my_auth_identifier.rb" do |content|
      assert_match(/class MyAuthIdentifier < ActionMCP::GatewayIdentifier/, content)
      assert_match(/identifier :user/, content)
      assert_match(/authenticates :api_key/, content)
      assert_match(/def resolve/, content)
    end
  end

  test "generates identifier with custom identity" do
    run_generator [ "AdminAuth", "--auth-method=admin_token", "--identity=admin" ]

    assert_file "app/mcp/identifiers/admin_auth_identifier.rb" do |content|
      assert_match(/identifier :admin/, content)
      assert_match(/authenticates :admin_token/, content)
    end
  end

  test "generates identifier with database lookup method" do
    run_generator [ "ApiKey", "--auth-method=api_key", "--lookup-method=database" ]

    assert_file "app/mcp/identifiers/api_key_identifier.rb" do |content|
      assert_match(/api_key = extract_api_key/, content)
      assert_match(/User\.find_by\(api_key: api_key\)/, content)
    end
  end

  test "generates identifier with middleware lookup method" do
    run_generator [ "Warden", "--auth-method=warden", "--lookup-method=middleware" ]

    assert_file "app/mcp/identifiers/warden_identifier.rb" do |content|
      assert_match(/user = user_from_middleware/, content)
    end
  end

  test "generates identifier with headers lookup method" do
    run_generator [ "HeaderAuth", "--auth-method=headers", "--lookup-method=headers" ]

    assert_file "app/mcp/identifiers/header_auth_identifier.rb" do |content|
      assert_match(/HTTP_X_USER_ID/, content)
      assert_match(/HTTP_X_USER_EMAIL/, content)
    end
  end

  test "generates identifier with session lookup method" do
    run_generator [ "Session", "--auth-method=session", "--lookup-method=database" ]

    assert_file "app/mcp/identifiers/session_identifier.rb" do |content|
      assert_match(/session&\.\[\]/, content)
      assert_match(/User\.find_by\(id: user_id\)/, content)
    end
  end

  test "generates identifier with custom lookup method" do
    run_generator [ "Custom", "--auth-method=custom", "--lookup-method=custom" ]

    assert_file "app/mcp/identifiers/custom_identifier.rb" do |content|
      assert_match(/TODO: Implement your custom authentication logic/, content)
      assert_match(/NotImplementedError/, content)
    end
  end

  test "handles names ending with 'Identifier'" do
    run_generator [ "MyAuthIdentifier", "--auth-method=api_key" ]

    assert_file "app/mcp/identifiers/my_auth_identifier.rb" do |content|
      assert_match(/class MyAuthIdentifier < ActionMCP::GatewayIdentifier/, content)
    end
  end
end

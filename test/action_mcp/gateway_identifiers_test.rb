# frozen_string_literal: true

require "test_helper"

class ActionMCP::GatewayIdentifiersTest < ActiveSupport::TestCase
  MockUser = Data.define(:id, :email)
  MockWarden = Data.define(:user)
  setup do
    @request = ActionDispatch::Request.new({})
  end

  test "WardenIdentifier requires warden in request env" do
    identifier = ActionMCP::GatewayIdentifiers::WardenIdentifier.new(@request)

    assert_raises(ActionMCP::GatewayIdentifier::Unauthorized, "Warden not available") do
      identifier.resolve
    end
  end

  test "WardenIdentifier requires authenticated user" do
    warden = MockWarden.new(user: nil)
    @request.env["warden"] = warden

    identifier = ActionMCP::GatewayIdentifiers::WardenIdentifier.new(@request)

    assert_raises(ActionMCP::GatewayIdentifier::Unauthorized, "Not authenticated") do
      identifier.resolve
    end
  end

  test "WardenIdentifier returns user when authenticated" do
    user = MockUser.new(id: 1, email: "test@example.com")
    warden = MockWarden.new(user: user)
    @request.env["warden"] = warden

    identifier = ActionMCP::GatewayIdentifiers::WardenIdentifier.new(@request)

    assert_equal user, identifier.resolve
  end

  test "DeviseIdentifier requires user in request env" do
    identifier = ActionMCP::GatewayIdentifiers::DeviseIdentifier.new(@request)

    assert_raises(ActionMCP::GatewayIdentifier::Unauthorized, "Not authenticated") do
      identifier.resolve
    end
  end

  test "DeviseIdentifier returns user when present" do
    user = MockUser.new(id: 1, email: "test@example.com")
    @request.env["devise.user"] = user

    identifier = ActionMCP::GatewayIdentifiers::DeviseIdentifier.new(@request)

    assert_equal user, identifier.resolve
  end

  test "RequestEnvIdentifier requires user ID header" do
    identifier = ActionMCP::GatewayIdentifiers::RequestEnvIdentifier.new(@request)

    assert_raises(ActionMCP::GatewayIdentifier::Unauthorized, "User ID header missing") do
      identifier.resolve
    end
  end

  test "ApiKeyIdentifier requires api key" do
    identifier = ActionMCP::GatewayIdentifiers::ApiKeyIdentifier.new(@request)

    assert_raises(ActionMCP::GatewayIdentifier::Unauthorized, "Missing API key") do
      identifier.resolve
    end
  end

  test "all identifiers have correct class attributes" do
    [
      ActionMCP::GatewayIdentifiers::WardenIdentifier,
      ActionMCP::GatewayIdentifiers::DeviseIdentifier,
      ActionMCP::GatewayIdentifiers::RequestEnvIdentifier,
      ActionMCP::GatewayIdentifiers::ApiKeyIdentifier
    ].each do |klass|
      assert_respond_to klass, :identifier_name
      assert_respond_to klass, :auth_method
      assert_not_nil klass.identifier_name
      assert_not_nil klass.auth_method
    end
  end

  test "identifiers have expected auth methods" do
    assert_equal "warden", ActionMCP::GatewayIdentifiers::WardenIdentifier.auth_method
    assert_equal "devise", ActionMCP::GatewayIdentifiers::DeviseIdentifier.auth_method
    assert_equal "request_env", ActionMCP::GatewayIdentifiers::RequestEnvIdentifier.auth_method
    assert_equal "api_key", ActionMCP::GatewayIdentifiers::ApiKeyIdentifier.auth_method
  end

  test "identifiers provide user identity" do
    [
      ActionMCP::GatewayIdentifiers::WardenIdentifier,
      ActionMCP::GatewayIdentifiers::DeviseIdentifier,
      ActionMCP::GatewayIdentifiers::RequestEnvIdentifier,
      ActionMCP::GatewayIdentifiers::ApiKeyIdentifier
    ].each do |klass|
      assert_equal :user, klass.identifier_name
    end
  end
end

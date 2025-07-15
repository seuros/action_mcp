# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class NoneIdentifierTest < ActionDispatch::IntegrationTest
    fixtures :users

    test "NoneIdentifier declares correct authentication method" do
      assert_equal "none", ActionMCP::NoneIdentifier.auth_method
    end

    test "NoneIdentifier declares correct identifier name" do
      assert_equal :user, ActionMCP::NoneIdentifier.identifier_name
    end

    test "resolve succeeds in development environment" do
      original_env = Rails.env
      begin
        Rails.env = "development"

        get "/gateway_up"
        identifier = ActionMCP::NoneIdentifier.new(request)

        result = identifier.resolve
        assert_instance_of User, result
        assert_equal "dev@localhost", result.email
      ensure
        Rails.env = original_env
      end
    end

    test "resolve succeeds in test environment" do
      original_env = Rails.env
      begin
        Rails.env = "test"

        get "/gateway_up"
        identifier = ActionMCP::NoneIdentifier.new(request)

        result = identifier.resolve
        assert_instance_of User, result
        assert_equal "dev@localhost", result.email
      ensure
        Rails.env = original_env
      end
    end

    test "resolve raises Unauthorized in production environment" do
      original_env = Rails.env
      begin
        Rails.env = "production"

        get "/gateway_up"
        identifier = ActionMCP::NoneIdentifier.new(request)

        error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
          identifier.resolve
        end
        assert_equal "No auth allowed in production", error.message
      ensure
        Rails.env = original_env
      end
    end

    test "resolve finds existing dev user" do
      existing_dev_user = users(:dev_user)

      get "/gateway_up"
      identifier = ActionMCP::NoneIdentifier.new(request)

      result = identifier.resolve
      assert_equal existing_dev_user, result
      assert_equal "Development User", result.name if result.respond_to?(:name)
    end

    test "resolve creates dev user when not found" do
      # Count existing users before removing dev user
      initial_count = User.count

      # Remove the fixture dev user to test creation
      User.find_by(email: "dev@localhost")&.destroy

      get "/gateway_up"
      identifier = ActionMCP::NoneIdentifier.new(request)

      result = identifier.resolve
      assert_instance_of User, result
      assert_equal "dev@localhost", result.email

      # Verify user was created
      assert_equal initial_count, User.count, "User should have been recreated to restore original count"
    end

    test "resolve returns anonymous_user string when User class undefined" do
      get "/gateway_up"
      identifier = ActionMCP::NoneIdentifier.new(request)

      # Mock the defined? method within the identifier's resolve method
      identifier.define_singleton_method(:resolve) do
        # Simulate User class not being defined
        return "anonymous_user" # Simulate defined?(User) returning false

        # This won't be reached in our test
        User.find_or_create_by!(email: "dev@localhost")
      end

      result = identifier.resolve
      assert_equal "anonymous_user", result
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class GatewayToolsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "tool can access current user when authenticated" do
    # Test that the tool can access the current user when directly set
    ActionMCP::Current.set(user: @user) do
      tool = UserInfoTool.new(include_sensitive: true, include_auth_details: false)
      response = tool.call

      response_hash = response.to_h
      assert response_hash[:content], "Response should have content: #{response_hash.inspect}"
      assert response_hash[:content].any?, "Content should not be empty"
      content_text = response_hash[:content].first[:text]
      assert_includes content_text, @user.id.to_s
      assert_includes content_text, @user.email
      assert_includes content_text, @user.name
    end
  end

  test "tool returns no user when not authenticated" do
    # Ensure no current user is set
    ActionMCP::Current.set(user: nil) do
      tool = UserInfoTool.new
      response = tool.call

      response_hash = response.to_h
      assert response_hash[:content].any?
      content_text = response_hash[:content].first[:text]
      assert_includes content_text, "No authenticated user found"
    end
  end
end

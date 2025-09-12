# frozen_string_literal: true

require "test_helper"

class UserInfoToolTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "user info basic functionality shows help when no user authenticated" do
    tool = UserInfoTool.new
    response = tool.call

    # In test environment, no user is authenticated, so it should show help
    assert_match(/No authenticated user found/, response.to_h[:content][0][:text])
    assert_match(/Session-based/, response.to_h[:content][0][:text])
    assert_match(/Bearer token/, response.to_h[:content][0][:text])
    assert_match(/API key/, response.to_h[:content][0][:text])
  end

  test "user info with sensitive info flag shows help when no user authenticated" do
    tool = UserInfoTool.new(include_sensitive: true)
    response = tool.call

    # Should show help when no user is authenticated
    assert_match(/No authenticated user found/, response.to_h[:content][0][:text])
  end

  test "user info with auth details flag shows help when no user authenticated" do
    tool = UserInfoTool.new(include_auth_details: true)
    response = tool.call

    # Should show help when no user is authenticated
    assert_match(/No authenticated user found/, response.to_h[:content][0][:text])
  end
end

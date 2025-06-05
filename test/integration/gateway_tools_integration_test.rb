require "test_helper"

class GatewayToolsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
    @token = JWT.encode({ user_id: @user.id }, ActionMCP::JwtDecoder.secret, ActionMCP::JwtDecoder.algorithm)
  end

  test "tool can access current user when authenticated" do
    # First authenticate via gateway
    get "/gateway_up", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :success

    # Now test that the tool can access the current user
    tool = UserInfoTool.new(include_email: true)

    # Simulate the gateway being called in the request context
    ActionMCP::Current.user = @user

    response = tool.call

    assert response.contents.any?
    content = response.contents.first
    assert_includes content.text, @user.id.to_s
    assert_includes content.text, @user.email
  end

  test "tool returns no user when not authenticated" do
    tool = UserInfoTool.new

    # Ensure no current user is set
    ActionMCP::Current.user = nil

    response = tool.call

    assert response.contents.any?
    content = response.contents.first
    assert_equal "No authenticated user", content.text
  end
end

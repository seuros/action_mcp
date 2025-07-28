# frozen_string_literal: true

require "ostruct"

# Identifier that requires no authentication - allows access for everyone
class NoneIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :none

  def resolve
    # Return a user-like object with all expected properties for development
    user = OpenStruct.new(
      id: "dev_user",
      email: "dev@localhost",
      name: "Development User",
      active: true,
      last_login_at: Time.current,
      api_key: "dev_api_key_123",
      password_digest: "fake_digest",
      created_at: Time.current - 1.day,
      updated_at: Time.current
    )

    user
  end
end

# frozen_string_literal: true

# Identifier that requires no authentication - allows access for everyone
class NoneIdentifier < ActionMCP::GatewayIdentifier
  DevUser = Data.define(:id, :email, :name, :active, :last_login_at, :api_key, :password_digest, :created_at, :updated_at)

  identifier :user
  authenticates :none

  def resolve
    # Return a user-like object with all expected properties for development
    DevUser.new(
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
  end
end

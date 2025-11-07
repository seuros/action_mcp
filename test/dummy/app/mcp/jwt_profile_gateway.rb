# frozen_string_literal: true

# Example Gateway that switches profiles based on authenticated identities
# This demonstrates how to use the apply_profile_from_authentication hook
# to implement role-based access control for MCP capabilities

class JwtProfileGateway < ActionMCP::Gateway
  # Override the hook to switch profiles based on authenticated identities
  def apply_profile_from_authentication(identities)
    # Switch profile based on identity attributes
    # This example shows how you would implement JWT-based role switching
    #
    # In practice, you would:
    # 1. Extract user info from the authenticated identity
    # 2. Check user attributes (like user.admin?)
    # 3. Call use_profile(:admin) or use_profile(:minimal) accordingly
    #
    # Example:
    #   if identities[:user]&.admin?
    #     use_profile(:admin)
    #   else
    #     use_profile(:minimal)
    #   end
  end

  private

  def use_profile(profile_name)
    # Implementation would set the profile on the current context
    # This is a placeholder for how you would switch profiles
    Rails.logger.info "Switching to profile: #{profile_name}"
  end
end

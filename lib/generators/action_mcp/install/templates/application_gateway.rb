# frozen_string_literal: true

# Application Gateway - configure your authentication identifiers here
#
# The Gateway reads from request.env keys set by upstream middleware
# (like Warden, Devise, or custom auth middleware) through identifier classes.
#
# ActionMCP provides ready-to-use identifier examples for common authentication patterns.
# You can use them directly or customize them for your needs.

class ApplicationGateway < ActionMCP::Gateway
  # Register your identifier classes in order of preference
  # The first successful identifier will be used

  # Option 1: Use built-in identifiers (recommended for common patterns)
  # identified_by ActionMCP::GatewayIdentifiers::WardenIdentifier  # For Warden/Devise
  # identified_by ActionMCP::GatewayIdentifiers::ApiKeyIdentifier  # For API key auth
  # identified_by ActionMCP::GatewayIdentifiers::RequestEnvIdentifier  # For custom headers

  # Option 2: Use multiple auth methods (tries in order)
  # identified_by ActionMCP::GatewayIdentifiers::WardenIdentifier,
  #               ActionMCP::GatewayIdentifiers::ApiKeyIdentifier

  # Option 3: Create custom identifiers (see examples below)
  # identified_by CustomUserIdentifier, CustomAdminIdentifier
end

# Custom identifier examples - uncomment and customize as needed:

# Example: Custom Warden/Devise identifier
# class CustomUserIdentifier < ActionMCP::GatewayIdentifier
#   identifier :user
#   authenticates :custom_warden
#
#   def resolve
#     user = user_from_middleware
#     raise Unauthorized, "No authenticated user found" unless user
#
#     # Add custom validation
#     raise Unauthorized, "User account suspended" if user.suspended?
#
#     user
#   end
# end

# Example: Custom API Key identifier with rate limiting
# class CustomApiKeyIdentifier < ActionMCP::GatewayIdentifier
#   identifier :user
#   authenticates :custom_api_key
#
#   def resolve
#     api_key = extract_api_key
#     raise Unauthorized, "Missing API key" unless api_key
#
#     user = User.find_by(api_key: api_key)
#     raise Unauthorized, "Invalid API key" unless user
#
#     # Add rate limiting check
#     if rate_limited?(user)
#       raise Unauthorized, "Rate limit exceeded"
#     end
#
#     user
#   end
#
#   private
#
#   def rate_limited?(user)
#     # Implement your rate limiting logic
#     false
#   end
# end

# Example: Admin-only identifier
# class AdminIdentifier < ActionMCP::GatewayIdentifier
#   identifier :admin
#   authenticates :admin_token
#
#   def resolve
#     token = extract_bearer_token
#     raise Unauthorized, "Missing admin token" unless token
#
#     admin = Admin.find_by(access_token: token)
#     raise Unauthorized, "Invalid admin token" unless admin
#
#     raise Unauthorized, "Admin access revoked" unless admin.active?
#
#     admin
#   end
# end

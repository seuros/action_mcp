# frozen_string_literal: true

class ApplicationGateway < ActionMCP::Gateway
  # Multiple authentication strategies for demonstrating Gateway patterns
  # These identifiers are tried in order until one succeeds

  # 1. JWT token authentication (for modern token-based auth)
  # 2. Session-based authentication (for web applications)
  # 3. Bearer token authentication (for modern APIs)
  # 4. API key authentication (for legacy APIs)
  # 5. Custom header authentication (for specialized integrations)
  # 6. None authentication (for development/testing)
  # 7. Test identifier for testing purposes
  identified_by JwtIdentifier, SessionIdentifier, BearerTokenIdentifier, ApiKeyIdentifier, CustomHeaderIdentifier, NoneIdentifier, TestIdentifier
end

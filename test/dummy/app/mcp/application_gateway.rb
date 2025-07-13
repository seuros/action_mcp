# frozen_string_literal: true

class ApplicationGateway < ActionMCP::Gateway
  # swap in whichever identifier classes you need,
  # in whatever order you need them to run.
  identified_by ActionMCP::JwtIdentifier, ActionMCP::OAuthIdentifier, ActionMCP::NoneIdentifier
end

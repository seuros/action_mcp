# frozen_string_literal: true

require "test_helper"

class HostAuthorizationMiddlewareTest < ActiveSupport::TestCase
  test "engine standalone stack excludes HostAuthorization when config.hosts is blank" do
    _ = ActionMCP::Engine.app
    built = ActionMCP::Engine.config.middleware
    refute_includes built.map(&:klass), ActionDispatch::HostAuthorization
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  # Regression coverage for the API-only host bug where
  # `ResourceTemplate#render_ui(template:)` used to call the host's
  # `::ApplicationController.render(...)` — which silently returned an empty
  # body when the host was API-only (`ApplicationController < ActionController::API`).
  #
  # The fix routes rendering through `ActionMCP::MCPAppRenderer`, which owns the
  # full ActionView stack regardless of host configuration.
  #
  # Gate this test with the env var so the default suite (full-Rails dummy)
  # stays untouched. Run with:
  #
  #   ACTION_MCP_API_ONLY=1 bundle exec rails test test/action_mcp/render_ui_api_only_test.rb
  class RenderUiApiOnlyTest < ActiveSupport::TestCase
    include ActionMCP::TestHelper

    setup do
      skip "Set ACTION_MCP_API_ONLY=1 to run API-only host regression" unless ENV["ACTION_MCP_API_ONLY"]
    end

    test "dummy ApplicationController is API-only in this run" do
      assert_operator ::ApplicationController, :<, ActionController::API,
                      "Test environment is not booted in API-only mode"
      refute_operator ::ApplicationController, :<, ActionController::Base,
                      "ApplicationController should not inherit from ActionController::Base in API-only mode"
    end

    test "ActionMCP::MCPAppRenderer renders a template even when host ApplicationController is API-only" do
      html = ActionMCP::MCPAppRenderer.render(template: "mcp/ui/weather_dashboard", layout: false)

      refute html.to_s.strip.empty?, "MCPAppRenderer produced empty output in API-only host"
      assert_includes html, "Weather"
    end

    test "render_ui(template:) returns non-empty content via WeatherDashboardTemplate in API-only host" do
      response = resolve_mcp_resource("ui://weather/dashboard")
      content = response.contents.first

      refute_nil content, "expected at least one content entry"
      refute content.text.to_s.strip.empty?, "render_ui produced empty text in API-only host"
      assert_includes content.text, "Weather"
    end
  end
end

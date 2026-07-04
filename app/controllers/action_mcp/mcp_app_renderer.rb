# frozen_string_literal: true

module ActionMCP
  # Internal renderer for `ResourceTemplate#render_ui(template:)`, the entry
  # point for MCP Apps UI views.
  #
  # Inherits from `ActionController::Base` so it always carries the full
  # ActionView stack regardless of whether the host Rails app is API-only.
  # Decoupling from the host's `ApplicationController` ensures `render_ui`
  # produces a non-empty body under `config.api_only = true`.
  #
  # Note: templates rendered through this controller intentionally do NOT
  # inherit host `ApplicationController` filters or `helper_method` exposure
  # (e.g., `current_user`). That decoupling is what makes `render_ui` work in
  # API-only hosts; reintroducing host coupling would bring the bug back.
  # Pass any data the template needs via the `locals:` argument to
  # `ResourceTemplate#render_ui`.
  #
  # Not routed. Not intended to be subclassed or used directly by host apps.
  class MCPAppRenderer < ActionController::Base
    helper ActionMCP::AppsHelper
  end
end

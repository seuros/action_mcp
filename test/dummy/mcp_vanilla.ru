# frozen_string_literal: true

# MCP Vanilla Server Configuration

# This configuration file creates a minimal Rack application for the MCP server
# with only the essential middleware needed for ActionMCP to function properly.
#
# USE THIS FILE when your main Rails application has middleware that interferes
# with MCP server operation, such as:
# - Devise/Warden (authentication middleware expecting cookies and sessions)
# - Ahoy (analytics tracking that intercepts requests)
# - Rack::Attack (rate limiting that might block MCP clients)
# - Rack::Cors (CORS headers that confuse AI assistants about their origin)
# - Custom authentication middleware
# - That sketchy middleware your coworker wrote at 3am that "temporarily" fixes login
# - The middleware that rejects any password except "hunter2" (we see you, IRC veteran)
# - Any middleware that expects web browser requests rather than API requests
#
# The Rails architecture makes engines inherit ALL middleware from the main app,
# which works great for 99% of use cases but can cause conflicts for protocol-specific
# servers like ActionMCP that don't need cookies, sessions, or authentication.
#
# To use this file:
# bundle exec rails s -c mcp_vanilla.ru -p 62770
# Or with Falcon:
# bundle exec falcon serve --bind http://0.0.0.0:62770 mcp_vanilla.ru

# Load the Rails environment
require_relative "config/environment"

# Ensure STDOUT is not buffered
$stdout.sync = true # for falcon

# Handle Ctrl+C gracefully when using Puma with streaming connections
Signal.trap("INT") do
  puts "\nReceived interrupt signal. Shutting down gracefully..."
  exit(0)
end

Signal.trap("TERM") do
  puts "\nReceived termination signal. Shutting down gracefully..."
  exit(0)
end

Rails.application.eager_load!

# Create a custom Rack app with only the middleware MCP needs
# This explicit middleware stack bypasses the Rails default middleware stack,
# avoiding any middleware that was auto-injected by gems in the main application
mcp_app = Rack::Builder.new do
  # Essential Rails middleware for request handling
  use ActionDispatch::HostAuthorization, Rails.application.config.hosts
  use Rack::Sendfile
  use ActionDispatch::Static, Rails.public_path
  use ActionDispatch::Executor, Rails.application.executor
  use ActionDispatch::ServerTiming
  use ActiveSupport::Cache::Strategy::LocalCache::Middleware
  use Rack::Runtime
  use Rack::MethodOverride
  use ActionDispatch::RequestId
  use ActionDispatch::RemoteIp, Rails.application.config.action_dispatch.ip_spoofing_check, Rails.application.config.action_dispatch.trusted_proxies
  use RailsAppVersion::AppInfoMiddleware if defined?(RailsAppVersion::AppInfoMiddleware)
  use Rails::Rack::Logger, Rails.application.config.log_tags
  use ActionDispatch::ShowExceptions, Rails.application.config.exceptions_app
  use ActionDispatch::DebugExceptions, Rails.application, ActionDispatch::DebugExceptions.interceptors
  use ActionDispatch::ActionableExceptions
  use ActionDispatch::Reloader
  use ActionDispatch::Callbacks
  use JSONRPC_Rails::Middleware::Validator

  run ActionMCP.server
end

run mcp_app

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

# Stub out Warden to prevent Devise errors
module Warden
  class Proxy
    def initialize(env)
      @env = env
      @users = {}
      @session_serializer = OpenStruct.new(
        serialize: ->(record) { record },
        deserialize: ->(data) { data },
        store: ->(user, scope) { @users[scope] = user },
        fetch: ->(scope) { @users[scope] },
        delete: ->(scope) { @users.delete(scope) }
      )
    end

    def user(scope = nil)
      nil
    end

    def authenticate(options = {})
      nil
    end

    def authenticate!(options = {})
      nil
    end

    def authenticated?(scope = nil)
      false
    end

    def session(scope = nil)
      {}
    end

    def env
      @env
    end

    def session_serializer
      @session_serializer
    end

    def config
      OpenStruct.new(
        default_scope: :user,
        scope_defaults: {},
        failure_app: ->(_) { [401, {}, ['Unauthorized']] }
      )
    end
  end
end

# Inject a fake Warden into the env
class WarddenInjector
  def initialize(app)
    @app = app
  end

  def call(env)
    env['warden'] = Warden::Proxy.new(env)
    begin
      @app.call(env)
    rescue => e
      puts "Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(10)
      raise
    end
  end
end

Rails.application.eager_load!

# Create a minimal Rack app that bypasses all middleware
# and goes directly to ActionMCP routes
mcp_app = Rack::Builder.new do
  use WarddenInjector
  use Rack::Runtime
  use ActionDispatch::RequestId, header: "X-Request-Id"
  use Rails::Rack::Logger, Rails.application.config.log_tags
  use ActionDispatch::Executor, Rails.application.executor
  use ActionDispatch::Reloader, Rails.application.executor
  use JSONRPC_Rails::Middleware::Validator, "/"

  # Run the ActionMCP routes directly
  run ActionMCP::Engine.routes
end

run mcp_app

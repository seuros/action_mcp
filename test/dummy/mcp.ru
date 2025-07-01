# frozen_string_literal: true

# Load the Rails environment
require_relative "config/environment"

# Ensure STDOUT is not buffered
$stdout.sync = true

Rails.application.eager_load!

# Add Rails logging middleware
use Rails::Rack::Logger
use ActionDispatch::RequestId, header: "X-Request-Id"

# Server is ready

# Add a simple health check endpoint
map "/health" do
  run lambda { |env| [ 200, { "Content-Type" => "text/plain" }, [ "OK" ] ] }
end

# Mount the MCP server at the root
map "/" do
  run ActionMCP.server
end

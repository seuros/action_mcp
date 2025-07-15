# frozen_string_literal: true

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

# Run the server directly - reloading will be handled internally for SSE compatibility
run ActionMCP.server

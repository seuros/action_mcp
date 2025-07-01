# frozen_string_literal: true

# Load the Rails environment
require_relative "config/environment"

# Ensure STDOUT is not buffered
$stdout.sync = true # for falcon

# Handle Ctrl+C gracefully when using Puma with streaming connections
Signal.trap("INT") do
  puts "\nReceived interrupt signal. Shutting down gracefully..."
  exit(0)
end  # Puma ghost us when it connect into a sse streaming connection, so we need to handle the INT signal to avoid ghost processes.

Signal.trap("TERM") do
  puts "\nReceived termination signal. Shutting down gracefully..."
  exit(0)
end

Rails.application.eager_load!

run ActionMCP.server

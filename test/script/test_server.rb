#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/action_mcp/server"
require "tempfile"
require "yaml"
require "fileutils"
require "concurrent"

# Helper method to wait for a condition to become true using Concurrent Ruby
def wait_for_condition(timeout = 5, interval = 0.01)
  # Create a promise that will check the condition in a loop
  future = Concurrent::Promises.future do
    result = false
    deadline = Time.now + timeout
    while Time.now < deadline
      begin
        if yield
          result = true
          break
        end
      rescue StandardError => e
        puts "Error in condition check: #{e.message}"
      end
      sleep interval
    end
    result
  end

  # Wait for the future to complete with a timeout
  begin
    future.value(timeout + 0.5) || false # Add a small buffer to the timeout
  rescue Concurrent::TimeoutError
    puts "Timed out waiting for condition"
    false
  rescue StandardError => e
    puts "Error waiting for condition: #{e.message}"
    false
  end
end

# Ensure the directory exists
FileUtils.mkdir_p(File.dirname(__FILE__))

# Create a test configuration file
config_file = Tempfile.new([ "test_mcp", ".yml" ])
config_file.write(YAML.dump({
                              "development" => {
                                "adapter" => "simple",
                                "min_threads" => 2,
                                "max_threads" => 5,
                                "max_queue" => 50
                              },
                              "production" => {
                                "adapter" => "solid_cable",
                                "polling_interval" => 0.5,
                                "min_threads" => 5,
                                "max_threads" => 10
                              }
                            }))
config_file.close

puts "Testing ActionMCP::Server with MCP configuration from #{config_file.path}"

# Create a server with the test configuration
server = ActionMCP::Server::ServerBase.new(config_file.path)

# Get the pubsub adapter
adapter = server.pubsub
puts "Adapter class: #{adapter.class}"

# Test subscribing to a channel
received_messages = []
callback = lambda { |message|
  puts "Received message: #{message}"
  received_messages << message
}

puts "Subscribing to test-channel..."
subscription_id = adapter.subscribe("test-channel", callback)
puts "Subscription ID: #{subscription_id}"

# Test broadcasting a message
puts "Broadcasting message to test-channel..."
adapter.broadcast("test-channel", "Hello, world!")

# Wait for the message to be received using wait_for_condition with Concurrent Ruby
message_received = wait_for_condition(5) { received_messages.include?("Hello, world!") }

if message_received
  puts "SUCCESS: Message was received"
else
  puts "ERROR: Message was not received within timeout"
  exit 1
end

# Add a small delay to ensure the message is fully processed
# Using a future with a timeout to avoid blocking indefinitely
timeout = 0.5
delay_future = Concurrent::Promises.future { sleep 0.2 }
puts "Warning: Delay timed out, continuing anyway" unless delay_future.wait(timeout)

# Test unsubscribing
puts "Unsubscribing from test-channel..."
adapter.unsubscribe("test-channel")

# Verify channel has no subscribers
if adapter.respond_to?(:subscribed_to?) && adapter.subscribed_to?("test-channel")
  puts "WARNING: Channel still has subscribers after unsubscribe"
end

# Test broadcasting a message after unsubscribing
puts "Broadcasting message after unsubscribe..."
adapter.broadcast("test-channel", "This should not be received")

# Use wait_for_condition with a shorter timeout to verify no message is received
unexpected_message_received = wait_for_condition(1) do
  received_messages.include?("This should not be received")
end

if unexpected_message_received
  puts "ERROR: Message was received after unsubscribe"
  exit 1
else
  puts "SUCCESS: No message received after unsubscribe"
end

# Clean up resources
begin
  # Shutdown the server gracefully to clean up thread pools
  puts "Shutting down server..."
  server.shutdown

  # Remove the temporary config file
  config_file.unlink
rescue StandardError => e
  puts "Error during cleanup: #{e.message}"
ensure
  puts "All tests passed!"
end

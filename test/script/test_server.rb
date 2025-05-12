#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/action_mcp/server"
require "tempfile"
require "yaml"
require "fileutils"

# Ensure the directory exists
FileUtils.mkdir_p(File.dirname(__FILE__))

# Create a test configuration file
config_file = Tempfile.new([ "test_mcp", ".yml" ])
config_file.write(YAML.dump({
  "development" => {
    "adapter" => "simple"
  },
  "production" => {
    "adapter" => "solid_cable",
    "polling_interval" => 0.5
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
callback = ->(message) {
  puts "Received message: #{message}"
  received_messages << message
}

puts "Subscribing to test-channel..."
subscription_id = adapter.subscribe("test-channel", callback)
puts "Subscription ID: #{subscription_id}"

# Test broadcasting a message
puts "Broadcasting message to test-channel..."
adapter.broadcast("test-channel", "Hello, world!")

# Wait for the message to be received
wait_for_condition(5) { received_messages.include?("Hello, world!") }

if received_messages.include?("Hello, world!")
  puts "SUCCESS: Message was received"
else
  puts "ERROR: Message was not received"
  exit 1
end

# Test unsubscribing
puts "Unsubscribing from test-channel..."
adapter.unsubscribe("test-channel")

# Test broadcasting a message after unsubscribing
puts "Broadcasting message after unsubscribe..."
adapter.broadcast("test-channel", "This should not be received")

# Wait to make sure no message is received
sleep 0.5

if received_messages.include?("This should not be received")
  puts "ERROR: Message was received after unsubscribe"
  exit 1
else
  puts "SUCCESS: No message received after unsubscribe"
end

# Clean up
config_file.unlink

puts "All tests passed!"

# Load the full Rails env *once* so you still get models, DB, Redis, etc.
require_relative "config/environment"

ActionMCP.configure { |c| c.mcp_endpoint_path = "/mcp" }
STDOUT.sync = true
STDERR.sync = true
run ActionMCP::Engine

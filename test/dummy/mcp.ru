# Load the full Rails env *once* so you still get models, DB, Redis, etc.
require_relative "config/environment"

STDOUT.sync = true
STDERR.sync = true
run ActionMCP::Engine

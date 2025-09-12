## Overview

ActionMCP is a Ruby gem that provides Model Context Protocol (MCP) capability to Ruby on Rails applications as a server. It is designed for production Rails environments and offers base classes for creating MCP applications.

## Test Setup and Execution

ActionMCP is a Rails engine that requires a dummy application context for testing. The dummy app is located in `test/dummy/`.

### Initial Test Setup

From the project root, set up the test database:

```bash
# Navigate to dummy app
cd test/dummy

# Install dependencies (if needed)
bundle install

# Reset database 
bundle exec rails db:drop db:create db:migrate
```

### Running Tests

From the project root:

```bash
# Run entire test suite
bundle exec rake app:test

# Run a specific test file
bundle exec rails test test/action_mcp_test.rb

# Run a specific test by line number
bundle exec rails test test/action_mcp_test.rb:6

# Run multiple test files or directories
bundle exec rails test test/controllers test/integration/tool_consent_test.rb
```


## Common Development Commands

### Linting

From the project root:

```bash
# Run linting
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a
```

### MCP Development Commands

From the project root:

```bash
bundle exec rake app:action_mcp:list_tools
bundle exec rake app:action_mcp:list_prompts
bundle exec rake app:action_mcp:list_resources

# Broken commands:
# bundle exec rake app:action_mcp:list_profiles # list profiles
# bundle exec rake app:action_mcp:list # list everything
# bundle exec rake app:action_mcp:info # show statistics

# Show specific profile configuration
bundle exec rake 'app:action_mcp:show_profile[profile_name]' # profile_name=primary (default)

# Install migrations from engine to dummy app
bundle exec rake app:action_mcp:install:migrations
```

### Starting the MCP Server

**Recommended methods (handle Ctrl+C properly):**

```bash
# From test/dummy directory - BEST OPTIONS
cd test/dummy && bin/sfalcon        # Falcon - best for streaming/SSE
cd test/dummy && bin/spuma          # Puma - good alternative

# Direct server commands (from project root)
bundle exec rackup test/dummy/mcp.ru -p 62770
bundle exec falcon serve --bind http://0.0.0.0:62770 --config test/dummy/mcp.ru
```

### Testing with MCP Inspector

```bash
# Start your MCP server first, then:
npx @modelcontextprotocol/inspector --url http://localhost:62770
```
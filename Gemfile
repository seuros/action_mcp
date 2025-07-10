# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in action_mcp.gemspec.
gemspec

gem "falcon"
gem "puma"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop", require: false
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
gem "debug", ">= 1.0.0"
gem "rails_app_version"
gem "railties"
gem "simplecov", require: false
# Optional PubSub adapters - at least one is recommended for production
gem "solid_mcp", "~> 0.2.3" # Database-backed adapter optimized for MCP
gem "solid_cache"
gem "solid_queue"

gem "annotaterb"

# Database adapters for testing
gem "pg"
gem "sqlite3", "~> 2.0"
# gem "redis"

gem "faraday" # used by the client
gem "webmock", group: :test # for testing HTTP requests

# File system watching for development
gem "listen", group: :development

gem "rubocop-minitest", "~> 0.38.1", group: :development

gem "rubocop-rake", "~> 0.7.1", group: :development

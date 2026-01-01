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

# Support testing against Rails edge/development branch
if ENV["RAILS_VERSION"] == "dev"
  gem "railties", github: "rails/rails", branch: "main"
else
  gem "railties", ENV.fetch("RAILS_VERSION", ">= 8.0.4")
end

gem "simplecov", require: false
# Optional PubSub adapters - at least one is recommended for production
gem "solid_cache"
gem "solid_mcp", "~> 0.2.3" # Database-backed adapter optimized for MCP
gem "solid_queue"

# Authentication for dummy app
gem "bcrypt", "~> 3.1.7"
gem "jwt"
gem "warden"


# Database adapters for testing
gem "pg"
gem "sqlite3", "~> 2.0"
# gem "redis"

gem "faraday" # used by the client
gem "webmock", group: :test # for testing HTTP requests
gem "database_cleaner-active_record", group: :test
gem "minitest", ">= 5.25", group: :test # Ensure minitest/mock is available
gem "minitest-reporters", group: :test
gem "maxitest", group: :test

# Optional: Schema validation for structured content
gem "json_schemer", ">= 2.4", group: [ :development, :test ]

# File system watching for development
gem "listen", group: :development

gem "rubocop-minitest", "~> 0.38.1", group: :development

gem "rubocop-rake", "~> 0.7.1", group: :development

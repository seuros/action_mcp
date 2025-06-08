# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in action_mcp.gemspec.
gemspec

gem "falcon"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop", require: false
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
gem "debug", ">= 1.0.0"
gem "rails_app_version"
gem "railties"
gem "simplecov", require: false
# Optional PubSub adapters - at least one is recommended for production
gem "solid_cable" # Database-backed adapter (no Redis needed)
gem "solid_cache"
gem "solid_queue"

gem "annotaterb"
gem "pg"
# gem "redis"

gem "faraday" # used by the client
gem "webmock", group: :test # for testing HTTP requests

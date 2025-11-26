# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Disable migration error check BEFORE loading defaults
    # Engine db/migrate timestamps differ from installed migrations in dummy/db/migrate
    config.active_record.migration_error = false

    config.load_defaults Rails::VERSION::STRING.to_f

    # Override again AFTER load_defaults in case it resets it
    config.active_record.migration_error = false

    config.action_mcp.name = "ActionMCP Dummy"
  end
end

# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Ensure STDOUT is not buffered for immediate log visibility
  $stdout.sync = true

  # Configure logger to output to STDOUT
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.logger.formatter = Logger::Formatter.new
  config.log_level = :debug

  # Reduce ActiveRecord query logging noise from solid_mcp
  config.active_record.logger = nil

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Use evented file watcher with listen gem for better performance
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Change to :null_store to avoid any caching.
  config.cache_store = :solid_cache_store

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
  ActionMCP::Server::TransportHandler.prepend(ActionMCP::TaggedStreamLogging)
end

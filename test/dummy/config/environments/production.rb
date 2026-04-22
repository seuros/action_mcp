# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot.
  config.eager_load = true

  config.consider_all_requests_local = false

  # Cache store
  config.cache_store = :null_store

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Log level
  config.log_level = :debug

  # Configure hosts for ActionDispatch::HostAuthorization
  # This protects against DNS rebinding attacks by only allowing requests from specified hosts
  config.hosts = %w[localhost 127.0.0.1]
end

# frozen_string_literal: true

class ConfigUpdateTool < ApplicationMCPTool
  tool_name "config_update"
  description "Update application configuration with structured input"

  # Input parameters using standard property declarations
  property :api_key, type: "string", required: true, description: "API authentication key"
  property :debug_mode, type: "boolean", default: false, description: "Enable debug logging"

  # Database configuration
  property :database_host, type: "string", required: true, default: "localhost", description: "Database hostname"
  property :database_port, type: "number", required: true, default: 5432, minimum: 1, maximum: 65535, description: "Database port"
  property :database_username, type: "string", required: true, description: "Database username"
  property :database_password, type: "string", description: "Database password"
  property :database_max_connections, type: "number", default: 10, minimum: 1, maximum: 100, description: "Maximum database connections"

  # Cache configuration
  property :cache_type, type: "string", required: true, enum: [ "memory", "redis" ], description: "Cache type"
  property :cache_ttl, type: "number", default: 3600, minimum: 60, description: "Time to live in seconds"
  property :cache_redis_host, type: "string", default: "localhost", description: "Redis host"
  property :cache_redis_port, type: "number", default: 6379, minimum: 1, maximum: 65535, description: "Redis port"
  property :cache_redis_password, type: "string", description: "Redis password"

  # CORS origins (simplified as comma-separated string)
  property :allowed_origins, type: "string", description: "Comma-separated list of allowed CORS origins"

  # Monitoring configuration
  property :monitoring_enabled, type: "boolean", default: true, description: "Enable monitoring"
  property :monitoring_endpoint, type: "string", format: "uri", description: "Monitoring endpoint URL"
  property :monitoring_interval, type: "number", default: 30, minimum: 5, description: "Monitoring interval in seconds"

  # Define output schema
  output_schema do
    boolean :success
    string :message

    object :updated_config do
      string :api_key
      boolean :debug_mode
      object :database do
        string :host
        number :port
        string :username
      end
    end

    array :warnings do
      string
    end
  end

  def perform
    # Access flat parameters using standard attribute access
    warnings = []

    # Validate API key format
    if api_key.length < 10
      warnings << "API key should be at least 10 characters long"
    end

    # Check database configuration
    if database_host == "localhost" && Rails.env.production?
      warnings << "Using localhost database in production environment"
    end

    # Validate cache configuration
    if cache_type == "redis" && cache_redis_host.nil?
      warnings << "Redis host not specified, using default"
    end

    # Check monitoring configuration
    if monitoring_enabled && monitoring_endpoint.nil?
      warnings << "Monitoring enabled but no endpoint specified"
    end

    # Simulate configuration update
    updated_config = {
      api_key: api_key,
      debug_mode: debug_mode || false,
      database: {
        host: database_host,
        port: database_port,
        username: database_username
      }
    }

    render text: "Configuration updated successfully!"
    render text: "Database: #{database_host}:#{database_port}"
    render text: "Cache type: #{cache_type}"

    if allowed_origins.present?
      origins_list = allowed_origins.split(",").map(&:strip)
      render text: "CORS origins: #{origins_list.join(', ')}"
    end

    if warnings.any?
      render text: "Warnings: #{warnings.join('; ')}"
    end

    # Return structured response matching output schema
    render structured: {
      success: true,
      message: "Configuration updated successfully",
      updated_config: updated_config,
      warnings: warnings
    }
  end
end

# frozen_string_literal: true

# Configure SolidMCP for the dummy app
SolidMCP.configure do |config|
  # Development-friendly settings
  config.batch_size = 100
  config.flush_interval = 0.05
  config.polling_interval = 0.1
  config.max_wait_time = 30

  # Short retention for testing
  config.delivered_retention = 5.minutes
  config.undelivered_retention = 30.minutes
end

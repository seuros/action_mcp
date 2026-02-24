# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"

require "simplecov"
SimpleCov.start

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

require "maxitest/autorun"
require "maxitest/timeout"
Maxitest.timeout = 5 # Kill any test hanging more than 5 seconds

require "action_mcp/test_helper"
require_relative "support/gateway_test_helper"

## Configure ActiveRecord Fixtures
# Note: maintain_test_schema! can cause issues with engine migrations
# since the engine db/migrate has different timestamps than installed migrations
# ActiveRecord::Migration.maintain_test_schema!
ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]

# Configure database cleaning strategy for SQLite (no transactions, use deletion)
if ApplicationRecord.connection.adapter_name == "SQLite"
  require "database_cleaner-active_record"

  ActiveSupport::TestCase.use_transactional_tests = false
  ActiveSupport::TestCase.parallelize(workers: 1)

  DatabaseCleaner[:active_record].strategy = :deletion

  class ActiveSupport::TestCase
    setup { DatabaseCleaner[:active_record].start }
    teardown { DatabaseCleaner[:active_record].clean }
  end
end


# MockProduct and MockOrder are in test/dummy/app/models/

module FixtureHelpers
  FIXTURE_CACHE = {}

  # Returns a *deep‑dup* of the parsed YAML so each test gets its own copy
  def load_fixture(name)
    FIXTURE_CACHE[name] ||= YAML.load_file(File.join(__dir__, "fixtures", "#{name}.yml"))
    FIXTURE_CACHE[name].deep_dup
  end
end

module ServerTestHelper
  # Wait for a condition to be true or timeout
  def wait_for_condition(timeout = 1, interval = 0.01)
    deadline = Time.now + timeout
    while Time.now < deadline
      return true if yield

      sleep interval
    end
    false
  end

  # Helper to ensure SolidMCP messages are flushed during tests
  def flush_solid_mcp_messages
    return unless defined?(SolidMCP::MessageWriter)

    SolidMCP::MessageWriter.instance.flush
    sleep 0.1 # Give subscribers time to process
  end

  # Create a temporary config file for testing
  def create_temp_config_file(config_hash)
    file = Tempfile.new([ "action_mcp_config", ".yml" ])
    file.write(YAML.dump(config_hash))
    file.close
    file
  end
end


module AuthenticationTestHelper
  # Temporarily override authentication configuration for a test
  def with_authentication_config(auth_methods)
    # Don't use Thread.current as it can leak between tests
    original_auth_methods = ActionMCP.configuration.authentication_methods.dup
    ActionMCP.configuration.authentication_methods = auth_methods
    yield
  ensure
    ActionMCP.configuration.authentication_methods = original_auth_methods
  end
end

ActiveSupport::TestCase.include(FixtureHelpers)
ActiveSupport::TestCase.include(ServerTestHelper)
ActiveSupport::TestCase.include(AuthenticationTestHelper)
ActiveSupport::TestCase.include(GatewayTestHelper)
ActionDispatch::IntegrationTest.include(AuthenticationTestHelper)
ActionDispatch::IntegrationTest.include(GatewayTestHelper)

# Ensure configuration is reset after each test
class ActionDispatch::IntegrationTest
  teardown do
    # Reset configuration to defaults loaded from mcp.yml
    ActionMCP.configuration.load_profiles
  end
end

Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |file| require file }

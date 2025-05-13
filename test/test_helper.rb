# frozen_string_literal: true

require "simplecov"
SimpleCov.start
# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"

require "action_mcp/test_helper"

class MockOrder
  def self.find_by(id:)
    new(id: id) if id.to_i.positive?
  end

  attr_reader :id

  def initialize(id:)
    @id = id
  end

  def to_json(*_args)
    { id: id }.to_json
  end
end

class MockProduct
  def self.find_by(id:)
    new(id: id) if id.to_i.positive?
  end

  attr_reader :id

  def initialize(id:)
    @id = id
  end

  def to_json(*_args)
    { id: id }.to_json
  end
end

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

  # Create a temporary config file for testing
  def create_temp_config_file(config_hash)
    file = Tempfile.new([ "action_mcp_config", ".yml" ])
    file.write(YAML.dump(config_hash))
    file.close
    file
  end
end

# frozen_string_literal: true
module LogHelpers
  def with_silenced_logger(target)
    original = target.logger
    log_io   = StringIO.new
    target.logger = ActiveSupport::TaggedLogging.new(Logger.new(log_io))
    yield log_io
  ensure
    target.logger = original
  end
end

ActiveSupport::TestCase.include(LogHelpers)
ActiveSupport::TestCase.include(FixtureHelpers)
ActiveSupport::TestCase.include(ServerTestHelper)

Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |file| require file }

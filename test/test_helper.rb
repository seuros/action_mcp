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

Minitest::Test.include(LogHelpers)
Minitest::Test.include(FixtureHelpers)

Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |file| require file }

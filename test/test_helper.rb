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
    new(id: id) if id.to_i > 0
  end

  attr_reader :id

  def initialize(id:)
    @id = id
  end

  def to_json
    { id: id }.to_json
  end
end

class MockProduct
  def self.find_by(id:)
    new(id: id) if id.to_i > 0
  end

  attr_reader :id

  def initialize(id:)
    @id = id
  end

  def to_json
    { id: id }.to_json
  end
end

# frozen_string_literal: true

require "simplecov"
SimpleCov.start
# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"

require "action_mcp/test_helper"

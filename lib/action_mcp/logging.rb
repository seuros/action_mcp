# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"
require "logger"
module ActionMCP
  module Logging
    extend ActiveSupport::Concern

    included do
      logger_instance = ActiveSupport::Logger.new(STDOUT)
      logger_instance.level = Logger.const_get(ActionMCP.configuration.logging_level.to_s.upcase)
      cattr_accessor :logger, default: ActiveSupport::TaggedLogging.new(logger_instance)
    end
  end
end

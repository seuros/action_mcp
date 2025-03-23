# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"
require "logger"

module ActionMCP
  # Module for providing logging functionality to ActionMCP transport.
  module Logging
    extend ActiveSupport::Concern

    # Included hook to configure the logger.
    included do
      cattr_accessor :logger, default: ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
    end
  end
end

# frozen_string_literal: true

class CalculateSumTool < ApplicationMCPTool
  description "Calculate the sum of two numbers"

  include ActionMCP::Callbacks
  include ActionMCP::Instrumentation

  property :a, type: "number", description: "The first number", required: true
  property :b, type: "number", description: "The second number", required: true

  validates :a, numericality: { less_than_or_equal_to: 100, message: "must be 100 or less" }

  # Class-level callback tracking for tests
  class << self
    attr_accessor :callback_tracker

    def reset_callback_tracker
      @callback_tracker = []
    end

    def track_callback(name)
      @callback_tracker ||= []
      @callback_tracker << name if Rails.env.test?
    end
  end

  before_perform do
    self.class.track_callback(:before_perform)
  end

  around_perform do |_tool, block|
    self.class.track_callback(:around_perform_before)
    block.call
    self.class.track_callback(:around_perform_after)
  end

  after_perform do
    self.class.track_callback(:after_perform)
  end

  def perform
    self.class.track_callback(:perform)
    sum = a + b
    render text: sum
  end
end

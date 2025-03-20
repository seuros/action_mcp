class CalculateSumTool < ApplicationMCPTool
  description "Calculate the sum of two numbers"

  include ActionMCP::Callbacks
  include ActionMCP::Instrumentation

  property :number1, type: "number", description: "The first number", required: true
  property :number2, type: "number", description: "The second number", required: true

  validates :number1, numericality: { less_than_or_equal_to: 100, message: "must be 100 or less" }

  before_perform do
    logger.tagged("CalculateSumTool") { logger.info("before_perform") }
  end

  around_perform do |tool, block|
    logger.tagged("CalculateSumTool") { logger.info("around_perform (before)") }
    block.call
    logger.tagged("CalculateSumTool") { logger.info("around_perform (after)") }
  end

  after_perform do
    logger.tagged("CalculateSumTool") { logger.info("after_perform") }
  end

  def perform
    logger.tagged("CalculateSumTool") { logger.info("perform") }
    sum = number1 + number2
    render text: sum
  end
end

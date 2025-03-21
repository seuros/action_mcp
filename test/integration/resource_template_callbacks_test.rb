require "test_helper"

class ResourceTemplateCallbacksTest < ActionDispatch::IntegrationTest
  test "callbacks are executed in the correct order for OrdersTemplate" do
    template = OrdersTemplate.new(customer_id: 1, order_id: 2)

    # Store the original logger
    original_logger = template.logger

    # Create a new logger that writes to our string IO
    log_output = StringIO.new
    template.logger = ActiveSupport::TaggedLogging.new(Logger.new(log_output))

    begin
      template.call

      # Get all the log lines
      log_lines = log_output.string.lines.map(&:strip)

      # Filter relevant log entries
      assert_match(/Starting to resolve order: 2 for customer: 1/, log_lines[0])
      assert_match(/Starting resolution for order: 2/, log_lines[1])
      assert_match(/Order 2 resolved successfully in .*s/, log_lines[2])
      assert_match(/Finished resolving order resource for order: 2/, log_lines[3])
    ensure
      # Restore the original logger
      template.logger = original_logger
    end
  end

  test "callbacks are executed in the correct order for ProductsTemplate" do
    template = ProductsTemplate.new(product_id: 3)

    # Store the original logger
    original_logger = template.logger

    # Create a new logger that writes to our string IO
    log_output = StringIO.new
    template.logger = ActiveSupport::TaggedLogging.new(Logger.new(log_output))

    begin
      template.call

      # Get all the log lines
      log_lines = log_output.string.lines.map(&:strip)

      # Filter relevant log entries
      assert_match(/Starting to resolve product: 3/, log_lines[0])
      assert_match(/Starting resolution for product: 3/, log_lines[1])
      assert_match(/Product 3 resolved successfully in .*s/, log_lines[2])
      assert_match(/Finished resolving product resource for product: 3/, log_lines[3])
    ensure
      # Restore the original logger
      template.logger = original_logger
    end
  end
end

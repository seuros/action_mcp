# frozen_string_literal: true

# test/action_mcp/execution_context_test.rb
require "test_helper"

module ActionMCP
  class ExecutionContextTest < ActiveSupport::TestCase
    setup do
      @session = Session.create!
    end

    test "capabilities can be initialized with execution context" do
      tool = CalculateSumTool.new(number1: 1, number2: 2)
      context = { session: @session, user: "admin" }

      tool.with_context(context)

      assert_equal context, tool.execution_context
      assert_equal @session, tool.execution_context[:session]
      assert_equal "admin", tool.execution_context[:user]
      assert_equal @session, tool.session
    end

    test "execution context persists through capability execution" do
      tool = CalculateSumTool.new(number1: 1, number2: 2)
      tool.with_context({ session: @session })

      # Create a tool that checks context during execution
      test_tool = Class.new(Tool) do
        tool_name "context_test"

        def perform
          render(text: "Session ID: #{session&.id}")
        end
      end

      instance = test_tool.new
      instance.with_context({ session: @session })
      result = instance.call

      assert_includes result.contents.first.text, @session.id
    end

    test "prompts support execution context" do
      prompt = GreetingPrompt.new(name: "Test")
      prompt.with_context({ session: @session })

      assert_equal @session, prompt.session
      assert_equal @session, prompt.execution_context[:session]
    end

    test "resource templates support execution context" do
      template = OrdersTemplate.new(customer_id: "123", order_id: "456")
      template.with_context({ session: @session })

      assert_equal @session, template.session
      assert_equal @session, template.execution_context[:session]
    end

    test "execution context is thread-safe" do
      tool1 = CalculateSumTool.new(number1: 1, number2: 2)
      tool2 = CalculateSumTool.new(number1: 3, number2: 4)
      session2 = Session.create!

      threads = []
      results = []

      threads << Thread.new do
        tool1.with_context({ session: @session })
        results << [ 1, tool1.session.id ]
      end

      threads << Thread.new do
        tool2.with_context({ session: session2 })
        results << [ 2, tool2.session.id ]
      end

      threads.each(&:join)

      assert_equal @session.id, results.find { |r| r[0] == 1 }[1]
      assert_equal session2.id, results.find { |r| r[0] == 2 }[1]
    end

    test "with_context returns self for chaining" do
      tool = CalculateSumTool.new(number1: 1, number2: 2)
      result = tool.with_context({ session: @session })

      assert_equal tool, result
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class PromptErrorReportingTest < ActiveSupport::TestCase
    test "an exception raised while performing is reported and answered as an internal error" do
      prompt = GreetingPrompt.new(name: "Ada")
      prompt.define_singleton_method(:perform) { raise ArgumentError, "prompt exploded" }
      response = nil

      report = assert_error_reported(ArgumentError) { response = prompt.call }

      assert_equal "prompt exploded", report.error.message
      assert response.is_error
      assert_equal "Unhandled Error executing prompt", response.to_h[:message]
    end
  end
end

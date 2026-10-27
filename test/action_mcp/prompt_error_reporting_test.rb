# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class PromptErrorReportingTest < ActiveSupport::TestCase
    setup do
      @prompt_class = Class.new(ApplicationMCPPrompt) do
        prompt_name "error_raising_prompt"
        description "A prompt that always raises"

        def perform
          raise ArgumentError, "prompt exploded"
        end
      end
    end

    teardown do
      @prompt_class.unregister_from_registry
    end

    test "an exception raised while performing is reported and answered as an internal error" do
      response = nil
      report = assert_error_reported(ArgumentError) { response = @prompt_class.new.call }

      assert_equal "prompt exploded", report.error.message
      assert response.is_error
      assert_equal "Unhandled Error executing prompt", response.to_h[:message]
    end
  end
end

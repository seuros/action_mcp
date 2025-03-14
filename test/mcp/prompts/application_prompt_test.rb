# frozen_string_literal: true

require "test_helper"
class ApplicationPromptTest < ActiveSupport::TestCase
  test "should be abstract" do
    assert ApplicationPrompt.abstract?
  end
end

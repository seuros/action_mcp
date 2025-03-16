# frozen_string_literal: true

require "test_helper"

class CarbonFootprintAssessmentPromptTest < ActiveSupport::TestCase
  test "should return a valid prompt" do
    params = {
      transportation_method: "car",
      household_size: 4,
      diet_type: "omnivore",
      location_type: "suburban" # optional; can be omitted or set to nil
    }

    prompt = CarbonFootprintAssessmentPrompt.new(**params)
    response = prompt.call
    assert_equal 8, response.messages.size
  end
end

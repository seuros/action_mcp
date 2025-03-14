# frozen_string_literal: true

class ApplicationToolTest < ActiveSupport::TestCase
  test "should be abstract" do
    assert ApplicationTool.abstract?
  end
end
